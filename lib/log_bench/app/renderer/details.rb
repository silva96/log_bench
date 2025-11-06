# frozen_string_literal: true

require "set"

module LogBench
  module App
    module Renderer
      class Details
        include Curses
        EMPTY_LINE = {text: "", color: nil}
        SEPARATOR_LINE = {text: "", color: nil, separator: true}

        def initialize(screen, state, scrollbar, ansi_renderer)
          self.screen = screen
          self.state = state
          self.scrollbar = scrollbar
          self.ansi_renderer = ansi_renderer
          self.cached_lines = nil
          self.cache_key = nil
        end

        def draw
          detail_win.erase
          detail_win.box(0, 0)

          draw_header
          draw_request_details
        end

        def get_cached_detail_lines(request)
          current_cache_key = build_cache_key(request)

          # Return cached lines if cache is still valid
          if cached_lines && cache_key == current_cache_key
            return cached_lines
          end

          # Cache is invalid, rebuild lines
          self.cached_lines = build_detail_lines(request)
          self.cache_key = current_cache_key
          cached_lines
        end

        def invalidate_cache
          self.cached_lines = nil
          self.cache_key = nil
        end

        private

        attr_accessor :screen, :state, :scrollbar, :ansi_renderer, :cached_lines, :cache_key

        def draw_header
          detail_win.setpos(0, 2)

          if state.right_pane_focused?
            detail_win.attron(color_pair(1) | A_BOLD) { detail_win.addstr(" Request Details ") }
          else
            detail_win.attron(color_pair(2) | A_DIM) { detail_win.addstr(" Request Details ") }
          end

          # Show detail filter to the right of the title (always visible when active)
          if state.detail_filter.present? || state.detail_filter.active?
            filter_text = "Filter: #{state.detail_filter.cursor_display}"

            # Position filter text to the right, leaving some space
            filter_x = detail_win.maxx - filter_text.length - 3
            if filter_x > 20  # Only show if there's enough space
              detail_win.setpos(0, filter_x)
              detail_win.attron(color_pair(4)) { detail_win.addstr(filter_text) }
            end
          end
        end

        def draw_request_details
          request = state.current_request
          return unless request

          lines = get_cached_detail_lines(request)
          visible_height = detail_win.maxy - 2

          adjust_detail_scroll(lines.size, visible_height)
          state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

          # Find all unique entry IDs and determine selected entry, excluding separator lines
          entry_ids = lines.reject { |line| line[:separator] }.map { |line| line[:entry_id] }.compact.uniq
          selected_entry_id = entry_ids[state.detail_selected_entry] if state.detail_selected_entry < entry_ids.size

          visible_lines = lines[state.detail_scroll_offset, visible_height] || []
          visible_lines.each_with_index do |line_data, i|
            y = i + 1  # Start at row 1 (after border)
            # Don't highlight separator lines
            is_selected = !line_data[:separator] && line_data[:entry_id] == selected_entry_id && state.right_pane_focused?

            # Draw highlight background if selected
            if is_selected
              detail_win.setpos(y, 1)
              detail_win.attron(color_pair(10) | A_DIM) do
                detail_win.addstr(" " * (detail_win.maxx - 2))
              end
            end

            detail_win.setpos(y, 2)

            # Handle multi-segment lines (for mixed colors)
            if line_data.is_a?(Hash) && line_data[:segments]
              line_data[:segments].each do |segment|
                if is_selected
                  detail_win.attron(color_pair(10) | A_DIM) { detail_win.addstr(segment[:text]) }
                elsif segment[:color]
                  detail_win.attron(segment[:color]) { detail_win.addstr(segment[:text]) }
                else
                  detail_win.addstr(segment[:text])
                end
              end
            elsif line_data.is_a?(Hash) && line_data[:raw_ansi]
              # Handle lines with raw ANSI codes (like colorized SQL)
              if is_selected
                # For selected ANSI lines, render without ANSI codes to maintain highlight
                plain_text = line_data[:text].gsub(/\e\[[0-9;]*m/, "")
                detail_win.attron(color_pair(10) | A_DIM) { detail_win.addstr(plain_text) }
              else
                ansi_renderer.parse_and_render(line_data[:text], detail_win)
              end
            elsif line_data.is_a?(Hash)
              # Handle single-color lines
              if is_selected
                detail_win.attron(color_pair(10) | A_DIM) { detail_win.addstr(line_data[:text]) }
              elsif line_data[:color]
                detail_win.attron(line_data[:color]) { detail_win.addstr(line_data[:text]) }
              else
                detail_win.addstr(line_data[:text])
              end
            elsif is_selected
              # Simple string
              detail_win.attron(color_pair(10) | A_DIM) { detail_win.addstr(line_data.to_s) }
            else
              detail_win.addstr(line_data.to_s)
            end
          end

          # Draw scrollbar if needed
          if lines.size > visible_height
            scrollbar.draw(detail_win, visible_height, state.detail_scroll_offset, lines.size)
          end
        end

        def build_cache_key(request)
          # Cache key includes factors that affect the rendered output
          [
            request.request_id,
            request.related_logs.size,
            state.detail_filter.display_text,
            detail_win.maxx  # Window width affects text wrapping
          ]
        end

        def build_detail_lines(request)
          lines = []
          entry_id = 0  # Track logical log entries
          # Cache window width to avoid repeated method calls
          window_width = detail_win.maxx
          max_width = window_width - 6  # Leave margin for borders and scrollbar

          # Method - separate label and value colors
          method_color = case request.method
          when "GET" then color_pair(3) | A_BOLD
          when "POST" then color_pair(4) | A_BOLD
          when "PUT" then color_pair(5) | A_BOLD
          when "DELETE" then color_pair(6) | A_BOLD
          else color_pair(2) | A_BOLD
          end

          lines << EMPTY_LINE.merge(entry_id: entry_id)
          entry_id += 1
          lines << {
            text: "Method: #{request.method}",
            color: nil,
            entry_id: entry_id,
            segments: [
              {text: "Method: ", color: color_pair(1)},
              {text: request.method, color: method_color}
            ]
          }

          # Path - allow multiple lines with proper color separation
          entry_id += 1
          add_path_lines(lines, request, max_width, entry_id)
          entry_id += 1
          add_status_duration_lines(lines, request, entry_id)
          entry_id += 1
          add_controller_lines(lines, request, entry_id)
          entry_id += 1
          add_request_id_lines(lines, request, entry_id)
          entry_id += 1
          add_request_timestamp_lines(lines, request, entry_id)
          entry_id += 1
          add_params_lines(lines, request, max_width, entry_id)
          entry_id += 1
          add_related_logs_section(lines, request, entry_id)

          lines
        end

        def add_path_lines(lines, request, max_width, entry_id)
          path_prefix = "Path: "
          remaining_path = request.path

          # First line starts after "Path: " (6 characters)
          first_line_width = max_width - path_prefix.length
          if remaining_path.length <= first_line_width
            lines << {
              text: path_prefix + remaining_path,
              color: nil,
              entry_id: entry_id,
              segments: [
                {text: path_prefix, color: color_pair(1)},
                {text: remaining_path, color: nil}  # Default white color
              ]
            }
          else
            # Split into multiple lines
            first_chunk = remaining_path[0, first_line_width]
            lines << {
              text: path_prefix + first_chunk,
              color: nil,
              entry_id: entry_id,
              segments: [
                {text: path_prefix, color: color_pair(1)},
                {text: first_chunk, color: nil}  # Default white color
              ]
            }
            remaining_path = remaining_path[first_line_width..]

            # Continue on subsequent lines
            while remaining_path.length > 0
              line_chunk = remaining_path[0, max_width]
              lines << {text: line_chunk, color: nil, entry_id: entry_id}  # Default white color
              remaining_path = remaining_path[max_width..] || ""
            end
          end
        end

        def add_status_duration_lines(lines, request, entry_id)
          if request.status
            # Add status color coding
            status_color = case request.status
            when 200..299 then color_pair(3)  # Green
            when 300..399 then color_pair(4)  # Yellow
            when 400..599 then color_pair(6)  # Red
            else color_pair(2)                # Default
            end

            # Build segments for mixed coloring
            segments = [
              {text: "Status: ", color: color_pair(1)},
              {text: request.status.to_s, color: status_color}
            ]

            if request.duration
              segments << {text: " | Duration: ", color: color_pair(1)}
              segments << {text: "#{request.duration}ms", color: nil}  # Default white color
            end

            status_text = segments.map { |s| s[:text] }.join
            lines << {
              text: status_text,
              color: nil,
              entry_id: entry_id,
              segments: segments
            }
          end
        end

        def add_controller_lines(lines, request, entry_id)
          if request.controller
            controller_value = "#{request.controller}##{request.action}"
            lines << {
              text: "Controller: #{controller_value}",
              color: nil,
              entry_id: entry_id,
              segments: [
                {text: "Controller: ", color: color_pair(1)},
                {text: controller_value, color: nil}  # Default white color
              ]
            }
          end
        end

        def add_params_lines(lines, request, max_width, entry_id)
          return unless request.params

          lines << EMPTY_LINE.merge(entry_id: entry_id)
          lines << {
            text: "Params:",
            color: nil,
            entry_id: entry_id,
            segments: [
              {text: "Params:", color: color_pair(1) | A_BOLD}
            ]
          }

          params_text = format_params(request.params)
          indent = "  "

          # Split the params text into lines that fit within the available width
          line_width = max_width - indent.length
          remaining_text = params_text

          while remaining_text && remaining_text.length > 0
            line_chunk = remaining_text[0, line_width]
            lines << {text: indent + line_chunk, color: nil, entry_id: entry_id}
            remaining_text = remaining_text[line_width..] || ""
          end
        end

        def format_params(params)
          case params
          when Hash
            # Format as readable key-value pairs
            if params.empty?
              "{}"
            else
              formatted_pairs = params.map do |key, value|
                formatted_value = case value
                when Hash
                  format_nested_hash(value)
                when Array
                  "[#{value.join(", ")}]"
                else
                  value.to_s
                end
                "#{key}: #{formatted_value}"
              end
              "{ #{formatted_pairs.join(", ")} }"
            end
          when String
            params
          else
            params.to_s
          end
        end

        def format_nested_hash(hash, depth = 1)
          return "{}" if hash.empty?

          if depth > 2  # Limit nesting depth to avoid overly complex display
            "{...}"
          else
            formatted_pairs = hash.map do |key, value|
              formatted_value = case value
              when Hash
                format_nested_hash(value, depth + 1)
              when Array
                "[#{value.join(", ")}]"
              else
                value.to_s
              end
              "#{key}: #{formatted_value}"
            end
            "{ #{formatted_pairs.join(", ")} }"
          end
        end

        def add_request_id_lines(lines, request, entry_id)
          if request.request_id
            lines << {
              text: "Request ID: #{request.request_id}",
              color: nil,
              entry_id: entry_id,
              segments: [
                {text: "Request ID: ", color: color_pair(1)},
                {text: request.request_id, color: nil}  # Default white color
              ]
            }
          end
        end

        def color_pair(n)
          screen.color_pair(n)
        end

        def add_request_timestamp_lines(lines, request, entry_id)
          if request.timestamp
            lines << {
              text: "Timestamp: #{request.timestamp.strftime("%Y-%m-%d %H:%M:%S UTC")}",
              color: nil,
              entry_id: entry_id,
              segments: [
                {text: "Timestamp: ", color: color_pair(1)},
                {text: request.timestamp.strftime("%Y-%m-%d %H:%M:%S UTC"), color: nil}  # Default white color
              ]
            }
          end
        end

        def detail_win
          screen.detail_win
        end

        def add_related_logs_section(lines, request, entry_id)
          # Related Logs (grouped by request_id) - only show non-HTTP request logs
          if request.request_id && request.related_logs && !request.related_logs.empty?
            related_logs = request.related_logs

            # Apply detail filter to related logs
            filtered_related_logs = filter_related_logs(related_logs)

            # Use QuerySummary for consistent formatting
            query_summary = QuerySummary.new(request)
            query_stats = query_summary.build_stats

            # Add query summary
            lines << EMPTY_LINE.merge(entry_id: entry_id)

            # Show filter status in summary if filtering is active
            summary_title = "Query Summary:"
            lines << {text: summary_title, color: color_pair(1) | A_BOLD, entry_id: entry_id}

            if query_stats[:total_queries] > 0
              # Use QuerySummary methods for consistent formatting
              summary_line = query_summary.build_summary_line(query_stats)
              lines << {text: "  #{summary_line}", color: color_pair(2), entry_id: entry_id}

              breakdown_line = query_summary.build_breakdown_line(query_stats)
              unless breakdown_line.empty?
                lines << {text: "  #{breakdown_line}", color: color_pair(2), entry_id: entry_id}
              end
            end

            entry_id += 1
            lines << EMPTY_LINE.merge(entry_id: entry_id)

            # Show filtered logs section
            if state.detail_filter.present?
              count_text = "(#{filtered_related_logs.size}/#{related_logs.size} shown)"
              logs_title_text = "Related Logs #{count_text}:"
              lines << {
                text: logs_title_text,
                color: nil,
                entry_id: entry_id,
                segments: [
                  {text: "Related Logs ", color: color_pair(1) | A_BOLD},
                  {text: count_text, color: A_DIM},
                  {text: ":", color: color_pair(1) | A_BOLD}
                ]
              }
            else
              lines << {text: "Related Logs:", color: color_pair(1) | A_BOLD, entry_id: entry_id}
            end

            # Use filtered logs for display - group SQL queries with their call source lines
            i = 0
            while i < filtered_related_logs.size
              current_log = filtered_related_logs[i]
              next_log = filtered_related_logs[i + 1] if i + 1 < filtered_related_logs.size

              entry_id += 1

              # Check if current log is a SQL/cache query followed by a call source line
              if [:sql, :cache].include?(current_log.type) && next_log && next_log.type == :sql_call_line
                # Group the query and call source together with the same entry_id
                render_padded_text_with_spacing(current_log.content, lines, entry_id, extra_empty_lines: 0, original_entry: current_log)
                render_padded_text_with_spacing(next_log.content, lines, entry_id, extra_empty_lines: 1, use_separator: true, original_entry: current_log)
                i += 2  # Skip the next log since we processed it
              else
                # Handle standalone logs
                case current_log.type
                when :sql, :cache
                  render_padded_text_with_spacing(current_log.content, lines, entry_id, extra_empty_lines: 0, original_entry: current_log)
                else
                  render_padded_text_with_spacing(current_log.content, lines, entry_id, extra_empty_lines: 1, original_entry: current_log)
                end
                i += 1
              end
            end
          end
        end

        def filter_related_logs(related_logs)
          # Filter related logs (SQL, cache, etc.) in the detail pane
          return related_logs unless state.detail_filter.present?

          matched_indices = Set.new

          # First pass: find direct matches
          related_logs.each_with_index do |log, index|
            next unless log.content && state.detail_filter.matches?(log.content)

            matched_indices.add(index)

            # Add context lines based on log type
            case log.type
            when :sql_call_line
              # If match is a sql_call_line, include the line below (the actual SQL query)
              matched_indices.add(index + 1) if index + 1 < related_logs.size
            when :sql, :cache
              # If match is a sql or cache, include the line above (the call stack line)
              if index > 0 && related_logs[index - 1].type == :sql_call_line
                matched_indices.add(index - 1)
              end
            end
          end

          # Return logs in original order - optimize array operations
          matched_indices.sort.map { |index| related_logs[index] }
        end

        def render_padded_text_with_spacing(text, lines, entry_id, extra_empty_lines: 1, use_separator: false, original_entry: nil)
          # Helper function that renders text with padding, breaking long text into multiple lines
          content_width = detail_win.maxx - 8  # Account for padding (4 spaces each side)

          # Automatically detect if text contains ANSI codes
          has_ansi = ansi_renderer.has_ansi_codes?(text)

          text_chunks = if has_ansi
            # For ANSI text, break it into properly sized chunks
            ansi_renderer.wrap_ansi_text(text, content_width)
          else
            # For plain text, break it into chunks
            ansi_renderer.wrap_plain_text(text, content_width)
          end

          # Render each chunk as a separate line with padding
          text_chunks.each_with_index do |chunk, index|
            line_data = if has_ansi
              {text: "  #{chunk}  ", color: nil, raw_ansi: true, entry_id: entry_id}
            else
              {text: "  #{chunk}  ", color: nil, entry_id: entry_id}
            end

            # Add original_entry reference to the first line of each entry
            line_data[:original_entry] = original_entry if index == 0 && original_entry

            lines << line_data
          end

          # Add extra empty lines after all chunks
          if use_separator
            extra_empty_lines.times { lines << SEPARATOR_LINE }
          else
            extra_empty_lines.times { lines << EMPTY_LINE.merge(entry_id: entry_id) }
          end
        end

        def adjust_detail_scroll(total_lines, visible_height)
          max_scroll = [total_lines - visible_height, 0].max
          state.detail_scroll_offset = state.detail_scroll_offset.clamp(0, max_scroll)
        end
      end
    end
  end
end
