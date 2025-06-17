# frozen_string_literal: true

require "set"

module LogBench
  module App
    module Renderer
      class Details
        include Curses
        EMPTY_LINE = {text: "", color: nil}

        def initialize(screen, state, scrollbar, ansi_renderer)
          self.screen = screen
          self.state = state
          self.scrollbar = scrollbar
          self.ansi_renderer = ansi_renderer
        end

        def draw
          detail_win.erase
          detail_win.box(0, 0)

          draw_header
          draw_request_details
        end

        private

        attr_accessor :screen, :state, :scrollbar, :ansi_renderer

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

          lines = build_detail_lines(request)
          visible_height = detail_win.maxy - 2

          adjust_detail_scroll(lines.size, visible_height)

          visible_lines = lines[state.detail_scroll_offset, visible_height] || []
          visible_lines.each_with_index do |line_data, i|
            y = i + 1  # Start at row 1 (after border)
            detail_win.setpos(y, 2)

            # Handle multi-segment lines (for mixed colors)
            if line_data.is_a?(Hash) && line_data[:segments]
              line_data[:segments].each do |segment|
                if segment[:color]
                  detail_win.attron(segment[:color]) { detail_win.addstr(segment[:text]) }
                else
                  detail_win.addstr(segment[:text])
                end
              end
            elsif line_data.is_a?(Hash) && line_data[:raw_ansi]
              # Handle lines with raw ANSI codes (like colorized SQL)
              ansi_renderer.parse_and_render(line_data[:text], detail_win)
            elsif line_data.is_a?(Hash)
              # Handle single-color lines
              if line_data[:color]
                detail_win.attron(line_data[:color]) { detail_win.addstr(line_data[:text]) }
              else
                detail_win.addstr(line_data[:text])
              end
            else
              # Simple string
              detail_win.addstr(line_data.to_s)
            end
          end

          # Draw scrollbar if needed
          if lines.size > visible_height
            scrollbar.draw(detail_win, visible_height, state.detail_scroll_offset, lines.size)
          end
        end

        def build_detail_lines(request)
          lines = []
          max_width = detail_win.maxx - 6  # Leave margin for borders and scrollbar

          # Convert request to log format for compatibility with original implementation
          log = request_to_log_format(request)

          # Method - separate label and value colors
          method_color = case log[:method]
          when "GET" then color_pair(3) | A_BOLD
          when "POST" then color_pair(4) | A_BOLD
          when "PUT" then color_pair(5) | A_BOLD
          when "DELETE" then color_pair(6) | A_BOLD
          else color_pair(2) | A_BOLD
          end

          lines << EMPTY_LINE
          lines << {
            text: "Method: #{log[:method]}",
            color: nil,
            segments: [
              {text: "Method: ", color: color_pair(1)},
              {text: log[:method], color: method_color}
            ]
          }

          # Path - allow multiple lines with proper color separation
          add_path_lines(lines, log, max_width)
          add_status_duration_lines(lines, log)
          add_controller_lines(lines, log)
          add_request_id_lines(lines, log)
          add_params_lines(lines, log, max_width)
          add_related_logs_section(lines, log)

          lines
        end

        def request_to_log_format(request)
          {
            method: request.method,
            path: request.path,
            status: request.status,
            duration: request.duration,
            controller: request.controller,
            action: request.action,
            params: request.params,
            request_id: request.request_id,
            related_logs: build_related_logs(request)
          }
        end

        def build_related_logs(request)
          related = []

          # Add all related logs from the request
          request.related_logs.each do |log|
            related << {
              type: log.type,
              content: log.content,
              timing: log.timing,
              timestamp: log.timestamp
            }
          end

          related
        end

        def add_path_lines(lines, log, max_width)
          path_prefix = "Path: "
          remaining_path = log[:path]

          # First line starts after "Path: " (6 characters)
          first_line_width = max_width - path_prefix.length
          if remaining_path.length <= first_line_width
            lines << {
              text: path_prefix + remaining_path,
              color: nil,
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
              segments: [
                {text: path_prefix, color: color_pair(1)},
                {text: first_chunk, color: nil}  # Default white color
              ]
            }
            remaining_path = remaining_path[first_line_width..]

            # Continue on subsequent lines
            while remaining_path.length > 0
              line_chunk = remaining_path[0, max_width]
              lines << {text: line_chunk, color: nil}  # Default white color
              remaining_path = remaining_path[max_width..] || ""
            end
          end
        end

        def add_status_duration_lines(lines, log)
          if log[:status]
            # Add status color coding
            status_color = case log[:status]
            when 200..299 then color_pair(3)  # Green
            when 300..399 then color_pair(4)  # Yellow
            when 400..599 then color_pair(6)  # Red
            else color_pair(2)                # Default
            end

            # Build segments for mixed coloring
            segments = [
              {text: "Status: ", color: color_pair(1)},
              {text: log[:status].to_s, color: status_color}
            ]

            if log[:duration]
              segments << {text: " | Duration: ", color: color_pair(1)}
              segments << {text: "#{log[:duration]}ms", color: nil}  # Default white color
            end

            status_text = segments.map { |s| s[:text] }.join
            lines << {
              text: status_text,
              color: nil,
              segments: segments
            }
          end
        end

        def add_controller_lines(lines, log)
          if log[:controller]
            controller_value = "#{log[:controller]}##{log[:action]}"
            lines << {
              text: "Controller: #{controller_value}",
              color: nil,
              segments: [
                {text: "Controller: ", color: color_pair(1)},
                {text: controller_value, color: nil}  # Default white color
              ]
            }
          end
        end

        def add_params_lines(lines, log, max_width)
          return unless log[:params]

          lines << EMPTY_LINE
          lines << {
            text: "Params:",
            color: nil,
            segments: [
              {text: "Params:", color: color_pair(1) | A_BOLD}
            ]
          }

          params_text = format_params(log[:params])
          indent = "  "

          # Split the params text into lines that fit within the available width
          line_width = max_width - indent.length
          remaining_text = params_text

          while remaining_text && remaining_text.length > 0
            line_chunk = remaining_text[0, line_width]
            lines << {text: indent + line_chunk, color: nil}
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

        def add_request_id_lines(lines, log)
          if log[:request_id]
            lines << {
              text: "Request ID: #{log[:request_id]}",
              color: nil,
              segments: [
                {text: "Request ID: ", color: color_pair(1)},
                {text: log[:request_id], color: nil}  # Default white color
              ]
            }
          end
        end

        def color_pair(n)
          screen.color_pair(n)
        end

        def detail_win
          screen.detail_win
        end

        def add_related_logs_section(lines, log)
          # Related Logs (grouped by request_id) - only show non-HTTP request logs
          if log[:request_id] && log[:related_logs] && !log[:related_logs].empty?
            related_logs = log[:related_logs]

            # Sort by timestamp
            related_logs.sort_by! { |l| l[:timestamp] || Time.at(0) }

            # Apply detail filter to related logs
            filtered_related_logs = filter_related_logs(related_logs)

            # Calculate query statistics (use original logs for stats)
            query_stats = calculate_query_stats(related_logs)

            # Add query summary
            lines << EMPTY_LINE

            # Show filter status in summary if filtering is active
            summary_title = "Query Summary:"
            lines << {text: summary_title, color: color_pair(1) | A_BOLD}

            if query_stats[:total_queries] > 0
              summary_line = "  #{query_stats[:total_queries]} queries"
              if query_stats[:total_time] > 0
                summary_line += " (#{query_stats[:total_time]}ms total"
                if query_stats[:cached_queries] > 0
                  summary_line += ", #{query_stats[:cached_queries]} cached"
                end
                summary_line += ")"
              elsif query_stats[:cached_queries] > 0
                summary_line += " (#{query_stats[:cached_queries]} cached)"
              end
              lines << {text: summary_line, color: color_pair(2)}

              # Breakdown by operation type
              breakdown_parts = []
              breakdown_parts << "#{query_stats[:select]} SELECT" if query_stats[:select] > 0
              breakdown_parts << "#{query_stats[:insert]} INSERT" if query_stats[:insert] > 0
              breakdown_parts << "#{query_stats[:update]} UPDATE" if query_stats[:update] > 0
              breakdown_parts << "#{query_stats[:delete]} DELETE" if query_stats[:delete] > 0
              breakdown_parts << "#{query_stats[:transaction]} TRANSACTION" if query_stats[:transaction] > 0
              breakdown_parts << "#{query_stats[:cache]} CACHE" if query_stats[:cache] > 0

              if !breakdown_parts.empty?
                breakdown_line = "  " + breakdown_parts.join(", ")
                lines << {text: breakdown_line, color: color_pair(2)}
              end
            end

            lines << EMPTY_LINE

            # Show filtered logs section
            if state.detail_filter.present?
              count_text = "(#{filtered_related_logs.size}/#{related_logs.size} shown)"
              logs_title_text = "Related Logs #{count_text}:"
              lines << {
                text: logs_title_text,
                color: nil,
                segments: [
                  {text: "Related Logs ", color: color_pair(1) | A_BOLD},
                  {text: count_text, color: A_DIM},
                  {text: ":", color: color_pair(1) | A_BOLD}
                ]
              }
            else
              lines << {text: "Related Logs:", color: color_pair(1) | A_BOLD}
            end

            # Use filtered logs for display
            filtered_related_logs.each do |related|
              case related[:type]
              when :sql, :cache
                render_padded_text_with_spacing(related[:content], lines, extra_empty_lines: 0)
              else
                render_padded_text_with_spacing(related[:content], lines, extra_empty_lines: 1)
              end
            end
          end
        end

        def calculate_query_stats(related_logs)
          stats = {
            total_queries: 0,
            total_time: 0.0,
            select: 0,
            insert: 0,
            update: 0,
            delete: 0,
            transaction: 0,
            cache: 0,
            cached_queries: 0
          }

          related_logs.each do |log|
            next unless [:sql, :cache].include?(log[:type])

            stats[:total_queries] += 1

            # Extract timing from the content
            if log[:timing]
              # Parse timing like "(1.2ms)" or "1.2ms"
              timing_str = log[:timing].gsub(/[()ms]/, "")
              timing_value = timing_str.to_f
              stats[:total_time] += timing_value
            end

            # Categorize by SQL operation and check for cache
            content = log[:content].upcase
            if content.include?("CACHE")
              stats[:cached_queries] += 1
              # Still categorize cached queries by their operation type
              if content.include?("SELECT")
                stats[:select] += 1
              elsif content.include?("INSERT")
                stats[:insert] += 1
              elsif content.include?("UPDATE")
                stats[:update] += 1
              elsif content.include?("DELETE")
                stats[:delete] += 1
              elsif content.include?("TRANSACTION") || content.include?("BEGIN") || content.include?("COMMIT") || content.include?("ROLLBACK")
                stats[:transaction] += 1
              end
            elsif content.include?("SELECT")
              stats[:select] += 1
            elsif content.include?("INSERT")
              stats[:insert] += 1
            elsif content.include?("UPDATE")
              stats[:update] += 1
            elsif content.include?("DELETE")
              stats[:delete] += 1
            elsif content.include?("TRANSACTION") || content.include?("BEGIN") || content.include?("COMMIT") || content.include?("ROLLBACK") || content.include?("SAVEPOINT")
              stats[:transaction] += 1
            end
          end

          # Round total time to 1 decimal place
          stats[:total_time] = stats[:total_time].round(1)

          stats
        end

        def filter_related_logs(related_logs)
          # Filter related logs (SQL, cache, etc.) in the detail pane
          return related_logs unless state.detail_filter.present?

          matched_indices = Set.new

          # First pass: find direct matches
          related_logs.each_with_index do |log, index|
            if log[:content] && state.detail_filter.matches?(log[:content])
              matched_indices.add(index)

              # Add context lines based on log type
              case log[:type]
              when :sql_call_line
                # If match is a sql_call_line, include the line below (the actual SQL query)
                if index + 1 < related_logs.size
                  matched_indices.add(index + 1)
                end
              when :sql, :cache
                # If match is a sql or cache, include the line above (the call stack line)
                if index > 0 && related_logs[index - 1][:type] == :sql_call_line
                  matched_indices.add(index - 1)
                end
              end
            end
          end

          # Return logs in original order
          matched_indices.to_a.sort.map { |index| related_logs[index] }
        end

        def render_padded_text_with_spacing(text, lines, extra_empty_lines: 1)
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
          text_chunks.each do |chunk|
            lines << if has_ansi
              {text: "  #{chunk}  ", color: nil, raw_ansi: true}
            else
              {text: "  #{chunk}  ", color: nil}
            end
          end

          # Add extra empty lines after all chunks
          extra_empty_lines.times do
            lines << EMPTY_LINE
          end

          text_chunks.length
        end

        def adjust_detail_scroll(total_lines, visible_height)
          max_scroll = [total_lines - visible_height, 0].max
          state.detail_scroll_offset = [state.detail_scroll_offset, max_scroll].min
          state.detail_scroll_offset = [state.detail_scroll_offset, 0].max
        end
      end
    end
  end
end
