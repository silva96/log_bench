# frozen_string_literal: true

module LogBench
  module App
    class MouseHandler
      include Curses

      def initialize(state, screen)
        self.state = state
        self.screen = screen
      end

      def handle_mouse_input
        with_warnings_suppressed do
          mouse_event = getmouse

          return unless mouse_event

          if mouse_event.bstate & BUTTON1_CLICKED != 0
            handle_mouse_click(mouse_event.x, mouse_event.y)
          end
        end
      rescue
        nil
      end

      private

      attr_accessor :state, :screen

      def handle_mouse_click(x, y)
        if click_in_left_pane?(x, y)
          # Switch to left pane if not already focused
          state.switch_to_left_pane unless state.left_pane_focused?

          if click_on_column_header_row?(y)
            handle_request_header_click(x)
            return
          end

          if click_on_request_filter_row?(y)
            handle_request_filter_click(x)
            return
          end

          # Convert click coordinates to request index
          request_index = click_to_request_index(y)
          return unless request_index

          old_selected = state.selected
          max_index = state.filtered_requests.size - 1
          state.selected = [request_index, max_index].min
          state.auto_scroll = false

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        elsif click_in_right_pane?(x, y)
          # Switch to right pane
          state.switch_to_right_pane unless state.right_pane_focused?
        end
      end

      def click_in_left_pane?(x, y)
        # Left pane spans from x=0 to panel_width
        # Header takes up first HEADER_HEIGHT lines
        # Request list starts at HEADER_HEIGHT + 1 (accounting for border)
        panel_width = screen.panel_width
        header_height = Screen::HEADER_HEIGHT

        x >= 0 && x < panel_width && y > header_height
      end

      def click_in_right_pane?(x, y)
        # Right pane starts after left panel + border width
        # From Screen: panel_width + PANEL_BORDER_WIDTH
        panel_width = screen.panel_width
        border_width = Screen::PANEL_BORDER_WIDTH
        header_height = Screen::HEADER_HEIGHT

        right_pane_start = panel_width + border_width

        x >= right_pane_start && y > header_height
      end

      def click_to_request_index(y)
        # Header takes up first 5 lines.
        # Request list rows start at RequestList::ROWS_START_Y inside log_win.
        header_height = screen_header_height
        list_header_offset = Renderer::RequestList::ROWS_START_Y

        row_in_list = y - header_height - list_header_offset
        return nil if row_in_list < 0

        # Convert to actual request index accounting for scroll
        state.scroll_offset + row_in_list
      end

      def click_on_request_filter_row?(y)
        y == screen_header_height + Renderer::RequestList::FILTER_ROW_Y
      end

      def click_on_column_header_row?(y)
        y == screen_header_height + Renderer::RequestList::COLUMN_HEADER_Y
      end

      def handle_request_header_click(x)
        selected_column = request_header_column_for_x(x)
        state.toggle_request_sort(selected_column) if selected_column
      end

      def request_header_column_for_x(x)
        start_x = Renderer::RequestList::HEADER_Y_OFFSET
        method_width = Renderer::RequestList::METHOD_WIDTH
        path_width = screen.panel_width - Renderer::RequestList::PATH_MARGIN
        status_width = Renderer::RequestList::STATUS_WIDTH

        method_start = start_x
        path_start = method_start + method_width
        status_start = path_start + path_width
        time_start = status_start + status_width

        ranges = [
          [:method, method_start...(method_start + method_width)],
          [nil, path_start...(path_start + path_width)],
          [:status, status_start...(status_start + status_width)],
          [:time, time_start...screen.panel_width]
        ]

        ranges.each do |column, range|
          return column if range.cover?(x)
        end

        nil
      end

      def handle_request_filter_click(x)
        selected_column = request_filter_column_for_x(x)
        state.exit_filter_mode
        state.select_request_filter_column(selected_column) if selected_column
        state.enter_filter_mode
      end

      def request_filter_column_for_x(x)
        start_x = Renderer::RequestList::HEADER_Y_OFFSET
        method_width = Renderer::RequestList::METHOD_WIDTH
        filter_right_edge = screen.panel_width - Renderer::RequestList::FILTER_RIGHT_EDGE_OFFSET

        path_start = start_x + method_width
        time_width = Renderer::RequestList::FILTER_TIME_WIDTH
        status_width = Renderer::RequestList::FILTER_STATUS_WIDTH
        time_start = filter_right_edge - time_width
        status_start = time_start - status_width
        path_width = [status_start - path_start, 1].max

        ranges = [
          [:method, start_x...(start_x + method_width)],
          [:path, path_start...(path_start + path_width)],
          [:status, status_start...(status_start + status_width)],
          [:time, time_start...(time_start + time_width)]
        ]

        ranges.each do |column, range|
          return column if range.cover?(x)
        end

        nil
      end

      def screen_header_height
        Screen::HEADER_HEIGHT
      end

      def with_warnings_suppressed
        old_verbose = $VERBOSE
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = old_verbose
      end
    end
  end
end
