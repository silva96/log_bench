# frozen_string_literal: true

module LogBench
  module App
    class MouseHandler
      include Curses

      # UI constants
      DEFAULT_VISIBLE_HEIGHT = 20

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
        header_height = 5 # Screen::HEADER_HEIGHT

        x >= 0 && x < panel_width && y > header_height
      end

      def click_in_right_pane?(x, y)
        # Right pane starts after left panel + border width
        # From Screen: panel_width + PANEL_BORDER_WIDTH
        panel_width = screen.panel_width
        border_width = 3 # Screen::PANEL_BORDER_WIDTH
        header_height = 5 # Screen::HEADER_HEIGHT

        right_pane_start = panel_width + border_width

        x >= right_pane_start && y > header_height
      end

      def click_to_request_index(y)
        # Header takes up first 5 lines
        # Request list has 1 line border at top, then 1 line for column headers
        # So actual request rows start at y = 7 (5 header + 1 border + 1 column header)
        header_height = 5
        list_header_offset = 2 # border + column header

        row_in_list = y - header_height - list_header_offset
        return nil if row_in_list < 0

        # Convert to actual request index accounting for scroll
        state.scroll_offset + row_in_list
      end

      def visible_height
        # Approximate visible height for calculations
        DEFAULT_VISIBLE_HEIGHT
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
