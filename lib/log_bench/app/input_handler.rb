# frozen_string_literal: true

module LogBench
  module App
    class InputHandler
      include Curses

      # Key codes
      TAB = 9
      CTRL_F = 6          # Page down
      CTRL_B = 2          # Page up
      CTRL_D = 4          # Half page down
      CTRL_U = 21         # Half page up
      CTRL_C = 3          # Quit
      ESC = 27            # Escape

      # UI constants
      DEFAULT_VISIBLE_HEIGHT = 20

      def initialize(state, screen, renderer = nil)
        self.state = state
        self.screen = screen
        self.renderer = renderer
        self.mouse_handler = MouseHandler.new(state, screen)
        self.copy_handler = CopyHandler.new(state, renderer)
      end

      def handle_input
        ch = getch
        return if ch == -1 || ch.nil?

        # Check if update modal should handle input first
        if renderer&.handle_modal_input(ch)
          return
        end

        if ch == KEY_MOUSE
          mouse_handler.handle_mouse_input
        elsif filter_mode_active?
          handle_filter_input(ch)
        else
          handle_navigation_input(ch)
        end
      end

      private

      attr_accessor :state, :screen, :renderer, :mouse_handler, :copy_handler

      def filter_mode_active?
        state.filter_mode || state.detail_filter_mode
      end

      def handle_filter_input(ch)
        case ch
        when 10, 13, 27  # Enter, Return, Escape
          state.exit_filter_mode
        when KEY_UP
          state.exit_filter_mode
          state.navigate_up
        when KEY_DOWN
          state.exit_filter_mode
          state.navigate_down
        when 127, 8  # Backspace
          state.backspace_filter
        else
          add_character_to_filter(ch)
        end
      end

      def add_character_to_filter(ch)
        return unless printable_character?(ch)

        char_to_add = if ch.is_a?(String)
          ch
        else
          ch.chr
        end

        state.add_to_filter(char_to_add)
        reset_selection_if_main_filter
      end

      def printable_character?(ch)
        if ch.is_a?(String)
          ch.length == 1 && ch.ord >= 32 && ch.ord <= 126
        elsif ch.is_a?(Integer)
          ch.between?(32, 126)
        else
          false
        end
      end

      def reset_selection_if_main_filter
        return unless state.filter_mode

        state.selected = 0
        state.scroll_offset = 0
      end

      def handle_navigation_input(ch)
        case ch
        when KEY_LEFT, "h", "H"
          state.switch_to_left_pane
        when KEY_RIGHT, "l", "L"
          state.switch_to_right_pane
        when TAB
          toggle_pane_focus
        when KEY_UP, "k", "K"
          handle_up_navigation
        when KEY_DOWN, "j", "J"
          handle_down_navigation
        when CTRL_F
          handle_page_down
        when CTRL_B
          handle_page_up
        when CTRL_D
          handle_half_page_down
        when CTRL_U
          handle_half_page_up
        when "g"
          handle_go_to_top
        when "G"
          handle_go_to_bottom
        when "a", "A"
          state.toggle_auto_scroll
        when "f", "F", "/"
          state.enter_filter_mode
        when "c", "C"
          if state.left_pane_focused?
            state.clear_filter
          else
            state.clear_detail_filter
          end
        when "s", "S"
          state.cycle_sort_mode
        when "q", "Q", CTRL_C
          state.stop!
        when "t", "T"
          state.toggle_text_selection_mode
          screen.turn_text_selection_mode(state.text_selection_mode?)
        when "y", "Y"
          copy_handler.copy_to_clipboard
        when ESC
          handle_escape
        end
      end

      def toggle_pane_focus
        if state.left_pane_focused?
          state.switch_to_right_pane
        else
          state.switch_to_left_pane
        end
      end

      def handle_up_navigation
        old_selected = state.selected if state.left_pane_focused?
        state.navigate_up
        if state.left_pane_focused?
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        end
      end

      def handle_down_navigation
        if state.left_pane_focused?
          old_selected = state.selected
          max_index = state.filtered_requests.size - 1
          state.selected = [state.selected + 1, max_index].min
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          state.navigate_down
        end
      end

      def handle_page_down
        if state.left_pane_focused?
          old_selected = state.selected
          page_size = visible_height
          max_index = state.filtered_requests.size - 1
          state.selected = [state.selected + page_size, max_index].min
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          page_size = visible_height
          state.detail_selected_entry += page_size
        end
      end

      def handle_page_up
        if state.left_pane_focused?
          old_selected = state.selected
          page_size = visible_height
          state.selected = [state.selected - page_size, 0].max
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          page_size = visible_height
          state.detail_selected_entry = [state.detail_selected_entry - page_size, 0].max
        end
      end

      def handle_half_page_down
        if state.left_pane_focused?
          old_selected = state.selected
          half_page = visible_height / 2
          max_index = state.filtered_requests.size - 1
          state.selected = [state.selected + half_page, max_index].min
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          half_page = visible_height / 2
          state.detail_selected_entry += half_page
        end
      end

      def handle_half_page_up
        if state.left_pane_focused?
          old_selected = state.selected
          half_page = visible_height / 2
          state.selected = [state.selected - half_page, 0].max
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          half_page = visible_height / 2
          state.detail_selected_entry = [state.detail_selected_entry - half_page, 0].max
        end
      end

      def handle_go_to_top
        if state.left_pane_focused?
          old_selected = state.selected
          state.selected = 0
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          state.detail_selected_entry = 0
        end
      end

      def handle_go_to_bottom
        if state.left_pane_focused?
          old_selected = state.selected
          max_index = state.filtered_requests.size - 1
          state.selected = [max_index, 0].max
          state.auto_scroll = false
          state.adjust_scroll_for_selection(visible_height)

          # Reset detail selection when switching requests
          if old_selected != state.selected
            state.reset_detail_selection
          end
        else
          # Set to a high value, will be adjusted by bounds checking
          state.detail_selected_entry = 999999
        end
      end

      def handle_escape
        if state.filter_mode || state.detail_filter_mode
          state.exit_filter_mode
        else
          state.clear_filter
        end
      end

      def visible_height
        # Approximate visible height for calculations
        DEFAULT_VISIBLE_HEIGHT
      end
    end
  end
end
