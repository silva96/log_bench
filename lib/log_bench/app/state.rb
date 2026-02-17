# frozen_string_literal: true

require "singleton"

module LogBench
  module App
    class State
      include Singleton

      REQUEST_FILTER_COLUMNS = %i[method path status time].freeze
      NUMERIC_COMPARATOR_REGEX = /\A(<=|>=|<|>)\s*(-?\d+(?:\.\d+)?)\z/
      NUMERIC_COMPARATOR_ONLY_REGEX = /\A(<=|>=|<|>)\s*\z/
      NUMERIC_RANGE_REGEX = /\A(-?\d+(?:\.\d+)?)\s*-\s*(-?\d+(?:\.\d+)?)\z/
      NUMERIC_VALUE_REGEX = /\A-?\d+(?:\.\d+)?\z/
      NUMERIC_COMPARISON_EPSILON = 0.0001

      attr_reader :main_filter, :sort, :detail_filter, :cleared_requests, :start_time, :stats, :total_queries, :active_request_filter_column
      attr_accessor :requests, :orphan_requests, :auto_scroll, :scroll_offset, :selected, :detail_scroll_offset, :detail_selected_entry, :text_selection_mode, :update_available, :update_version

      def initialize
        reset!
      end

      def reset!
        self.requests = []
        self.orphan_requests = []
        self.selected = 0
        self.scroll_offset = 0
        self.auto_scroll = true
        self.running = true
        self.focused_pane = :left
        self.detail_scroll_offset = 0
        self.detail_selected_entry = 0
        self.text_selection_mode = false
        self.main_filter = Filter.new
        self.detail_filter = Filter.new
        self.request_filters = build_request_filters
        self.active_request_filter_column = :path
        self.sort = Sort.new
        self.update_available = false
        self.update_version = nil
        self.cleared_requests = nil
        self.job_ids_map = {}
        self.start_time = Time.now
        self.stats = Stats.new
        self.total_queries = 0
      end

      def running?
        running
      end

      def stop!
        self.running = false
      end

      def toggle_auto_scroll
        self.auto_scroll = !auto_scroll
      end

      def toggle_text_selection_mode
        self.text_selection_mode = !text_selection_mode
      end

      def text_selection_mode?
        text_selection_mode
      end

      def set_update_available(version)
        self.update_available = true
        self.update_version = version
      end

      def dismiss_update_notification
        self.update_available = false
        self.update_version = nil
      end

      def update_available?
        update_available
      end

      def clear_filter
        if left_pane_focused?
          clear_requests_filter
        else
          clear_detail_filter
        end
      end

      def clear_requests_filter
        main_filter.clear
        request_filters.each_value(&:clear)
        self.selected = 0
        self.scroll_offset = 0
      end

      def clear_detail_filter
        detail_filter.clear
        self.detail_scroll_offset = 0
        self.detail_selected_entry = 0
      end

      def clear_requests
        if cleared_requests
          cleared_requests[:requests] += requests
          cleared_requests[:total_queries] += total_queries
        else
          self.cleared_requests = {
            requests: requests,
            selected: selected,
            scroll_offset: scroll_offset,
            detail_scroll_offset: detail_scroll_offset,
            detail_selected_entry: detail_selected_entry,
            total_queries: total_queries
          }
        end

        self.requests = []
        self.total_queries = 0
        self.selected = 0
        self.scroll_offset = 0
        self.detail_scroll_offset = 0
        self.detail_selected_entry = 0
      end

      def undo_clear_requests
        return unless cleared_requests

        # Append any new requests that came in after the clear to the restored requests
        restored_requests = cleared_requests[:requests] + requests

        self.requests = restored_requests
        self.total_queries = cleared_requests[:total_queries] + total_queries
        self.selected = cleared_requests[:selected]
        self.scroll_offset = cleared_requests[:scroll_offset]
        self.detail_scroll_offset = cleared_requests[:detail_scroll_offset]
        self.detail_selected_entry = cleared_requests[:detail_selected_entry]
        self.cleared_requests = nil
      end

      def can_undo_clear?
        !cleared_requests.nil?
      end

      def cycle_sort_mode
        sort.cycle
      end

      def toggle_request_sort(column)
        return unless sort.toggle_column(column)

        self.auto_scroll = false
        self.selected = 0
        self.scroll_offset = 0
      end

      def sort_arrow_for_column(column)
        sort.sort_arrow_for_column(column)
      end

      def switch_to_left_pane
        self.focused_pane = :left
      end

      def switch_to_right_pane
        self.focused_pane = :right
      end

      def left_pane_focused?
        focused_pane == :left
      end

      def right_pane_focused?
        focused_pane == :right
      end

      def enter_filter_mode
        if left_pane_focused?
          main_filter.enter_mode
          self.active_request_filter_column ||= :path
        else
          detail_filter.enter_mode
        end
      end

      def exit_filter_mode
        main_filter.exit_mode
        detail_filter.exit_mode
      end

      def add_to_filter(char)
        if main_filter.active?
          active_request_filter.add_character(char)
        elsif detail_filter.active?
          detail_filter.add_character(char)
        end
      end

      def backspace_filter
        if main_filter.active?
          active_request_filter.remove_character
        elsif detail_filter.active?
          detail_filter.remove_character
        end
      end

      def filter_mode
        main_filter.active?
      end

      def detail_filter_mode
        detail_filter.active?
      end

      def request_filter_columns
        REQUEST_FILTER_COLUMNS
      end

      def request_filter_for(column)
        request_filters[column]
      end

      def select_request_filter_column(column)
        return unless request_filter_columns.include?(column)

        self.active_request_filter_column = column
      end

      def next_request_filter_column
        switch_request_filter_column(1)
      end

      def previous_request_filter_column
        switch_request_filter_column(-1)
      end

      def request_filters_present?
        request_filters.values.any?(&:present?) || main_filter.present?
      end

      def filtered_requests
        filtered = requests.select { |req| request_matches_filters?(req) }

        sort.sort_requests(filtered)
      end

      def current_request
        filtered = filtered_requests
        return nil if selected >= filtered.size || filtered.empty?

        filtered[selected]
      end

      def navigate_up
        if left_pane_focused?
          self.selected = [selected - 1, 0].max
          self.auto_scroll = false
        else
          self.detail_selected_entry = [detail_selected_entry - 1, 0].max
        end
      end

      def navigate_down
        if left_pane_focused?
          max_index = filtered_requests.size - 1
          self.selected = [selected + 1, max_index].min
          self.auto_scroll = false
        else
          self.detail_selected_entry += 1
        end
      end

      def reset_detail_selection
        self.detail_selected_entry = 0
        self.detail_scroll_offset = 0
      end

      def adjust_scroll_for_selection(visible_height)
        return unless left_pane_focused?

        if selected < scroll_offset
          self.scroll_offset = selected
        elsif selected >= scroll_offset + visible_height
          self.scroll_offset = selected - visible_height + 1
        end
      end

      def adjust_auto_scroll(visible_height)
        return unless auto_scroll && !filtered_requests.empty?

        self.selected = filtered_requests.size - 1
        self.scroll_offset = [selected - visible_height + 1, 0].max
      end

      def adjust_scroll_bounds(visible_height)
        filtered = filtered_requests
        max_offset = [filtered.size - visible_height, 0].max
        self.scroll_offset = scroll_offset.clamp(0, max_offset)
      end

      def adjust_detail_scroll_for_entry_selection(visible_height, lines)
        return unless right_pane_focused?

        # Find all unique entry IDs, excluding separator lines
        entry_ids = lines.reject { |line| line[:separator] }.map { |line| line[:entry_id] }.compact.uniq
        max_entry_index = [entry_ids.size - 1, 0].max

        # Ensure detail_selected_entry is within bounds
        self.detail_selected_entry = detail_selected_entry.clamp(0, max_entry_index)

        # Find the first and last line of the selected entry
        selected_entry_id = entry_ids[detail_selected_entry]
        return unless selected_entry_id

        first_line_index = lines.find_index { |line| line[:entry_id] == selected_entry_id }
        return unless first_line_index

        # Find the last line of the selected entry (including any separator lines that follow)
        last_line_index = first_line_index
        (first_line_index + 1...lines.size).each do |i|
          if lines[i][:entry_id] == selected_entry_id || lines[i][:separator]
            last_line_index = i
          else
            break
          end
        end

        # Adjust scroll to keep the entire selected entry visible
        if first_line_index < detail_scroll_offset
          self.detail_scroll_offset = first_line_index
        elsif last_line_index >= detail_scroll_offset + visible_height
          self.detail_scroll_offset = last_line_index - visible_height + 1
        end
      end

      def register_job_enqueue(job_id, request_id)
        job_ids_map[job_id] = request_id
      end

      def request_id_for_job(job_id)
        job_ids_map[job_id]
      end

      def track_new_requests(new_requests)
        stats.track_requests(new_requests)
        # Update total queries counter
        self.total_queries += new_requests.sum(&:query_count)
      end

      def set_initial_query_count(requests)
        self.total_queries = requests.sum(&:query_count)
      end

      def elapsed_time
        Time.now - start_time
      end

      def requests_per_second
        stats.requests_per_second
      end

      def requests_per_minute
        stats.requests_per_minute
      end

      def queries_per_second
        stats.queries_per_second
      end

      def queries_per_minute
        stats.queries_per_minute
      end

      private

      attr_reader :request_filters
      attr_accessor :focused_pane, :running, :job_ids_map
      attr_writer :main_filter, :detail_filter, :sort, :cleared_requests, :start_time, :stats, :total_queries, :request_filters, :active_request_filter_column

      def build_request_filters
        REQUEST_FILTER_COLUMNS.to_h { |column| [column, Filter.new] }
      end

      def active_request_filter
        request_filter_for(active_request_filter_column) || request_filter_for(:path)
      end

      def switch_request_filter_column(direction)
        return unless request_filter_columns.include?(active_request_filter_column)

        current_index = request_filter_columns.index(active_request_filter_column)
        next_index = (current_index + direction) % request_filter_columns.length
        self.active_request_filter_column = request_filter_columns[next_index]
      end

      def request_matches_filters?(request)
        matches_legacy_main_filter?(request) && matches_column_filters?(request)
      end

      def matches_legacy_main_filter?(request)
        return true unless main_filter.present?

        main_filter.matches?(request.path) ||
          main_filter.matches?(request.method) ||
          main_filter.matches?(request.controller) ||
          main_filter.matches?(request.action) ||
          main_filter.matches?(request.status) ||
          main_filter.matches?(request.request_id)
      end

      def matches_column_filters?(request)
        request_filters.all? do |column, filter|
          next true unless filter.present?

          case column
          when :method
            filter.matches?(request.method)
          when :path
            filter.matches?(request.path)
          when :status
            numeric_filter_matches?(request.status, filter.display_text)
          when :time
            numeric_filter_matches?(request.duration, filter.display_text)
          else
            true
          end
        end
      end

      def numeric_filter_matches?(value, filter_text)
        return true if filter_text.nil?

        expression = filter_text.strip
        return true if expression.empty?
        return true if expression.match?(NUMERIC_COMPARATOR_ONLY_REGEX)
        return false if value.nil?

        if (comparison = expression.match(NUMERIC_COMPARATOR_REGEX))
          compare_numeric(value.to_f, comparison[1], comparison[2].to_f)
        elsif (range = expression.match(NUMERIC_RANGE_REGEX))
          min_value, max_value = [range[1].to_f, range[2].to_f].minmax
          value.to_f.between?(min_value, max_value)
        elsif expression.match?(NUMERIC_VALUE_REGEX)
          (value.to_f - expression.to_f).abs <= NUMERIC_COMPARISON_EPSILON
        else
          value.to_s.downcase.include?(expression.downcase)
        end
      end

      def compare_numeric(value, operator, threshold)
        case operator
        when "<" then value < threshold
        when "<=" then value <= threshold
        when ">" then value > threshold
        when ">=" then value >= threshold
        else false
        end
      end
    end
  end
end
