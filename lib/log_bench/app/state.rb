# frozen_string_literal: true

module LogBench
  module App
    class State
      attr_reader :main_filter, :sort, :detail_filter
      attr_accessor :requests, :auto_scroll, :scroll_offset, :selected, :detail_scroll_offset, :text_selection_mode

      def initialize
        self.requests = []
        self.selected = 0
        self.scroll_offset = 0
        self.auto_scroll = true
        self.running = true
        self.focused_pane = :left
        self.detail_scroll_offset = 0
        self.text_selection_mode = false
        self.main_filter = Filter.new
        self.detail_filter = Filter.new
        self.sort = Sort.new
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

      def clear_filter
        main_filter.clear
        self.selected = 0
        self.scroll_offset = 0
      end

      def clear_detail_filter
        detail_filter.clear
        self.detail_scroll_offset = 0
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
          self.detail_scroll_offset = [detail_scroll_offset - 1, 0].max
        end
      end

      def navigate_down
        if left_pane_focused?
          max_index = filtered_requests.size - 1
          self.selected = [selected + 1, max_index].min
          self.auto_scroll = false
        else
          self.detail_scroll_offset += 1
        end
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

      private

      attr_accessor :focused_pane, :running
      attr_writer :main_filter, :detail_filter, :sort
    end
  end
end
