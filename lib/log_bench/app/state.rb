# frozen_string_literal: true

module LogBench
  module App
    class State
      attr_reader :main_filter, :sort, :detail_filter, :cleared_requests
      attr_accessor :requests, :orphan_requests, :auto_scroll, :scroll_offset, :selected, :detail_scroll_offset, :detail_selected_entry, :text_selection_mode, :update_available, :update_version

      def initialize
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
        self.sort = Sort.new
        self.update_available = false
        self.update_version = nil
        self.cleared_requests = nil
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
        else
          self.cleared_requests = {
            requests: requests,
            selected: selected,
            scroll_offset: scroll_offset,
            detail_scroll_offset: detail_scroll_offset,
            detail_selected_entry: detail_selected_entry
          }
        end

        self.requests = []
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
          main_filter.add_character(char)
        elsif detail_filter.active?
          detail_filter.add_character(char)
        end
      end

      def backspace_filter
        if main_filter.active?
          main_filter.remove_character
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

      def filtered_requests
        filtered = if main_filter.present?
          requests.select do |req|
            main_filter.matches?(req.path) ||
              main_filter.matches?(req.method) ||
              main_filter.matches?(req.controller) ||
              main_filter.matches?(req.action) ||
              main_filter.matches?(req.status) ||
              main_filter.matches?(req.request_id)
          end
        else
          requests
        end

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

      private

      attr_accessor :focused_pane, :running
      attr_writer :main_filter, :detail_filter, :sort, :cleared_requests
    end
  end
end
