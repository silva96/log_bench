# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class UpdateModal
        include Curses

        # Modal dimensions
        MODAL_WIDTH = 40
        MODAL_HEIGHT = 7
        COUNTDOWN_SECONDS = 5

        # Color constants
        HEADER_CYAN = 1
        SUCCESS_GREEN = 3
        WARNING_YELLOW = 4

        def initialize(screen, state)
          self.screen = screen
          self.state = state
          self.countdown = COUNTDOWN_SECONDS
          self.modal_win = nil
          self.last_countdown_update = Time.now
          self.dismissed = false
        end

        def should_show?
          state.update_available? && !dismissed
        end

        def draw
          return unless should_show?

          create_modal_window
          update_countdown_timer
          draw_content
          modal_win&.refresh
        end

        def handle_input(ch)
          return false unless should_show?

          # Any key dismisses the modal
          if ch != -1
            dismiss_modal
            return true
          end

          false
        end

        private

        attr_accessor :screen, :state, :countdown, :modal_win, :last_countdown_update, :dismissed

        def create_modal_window
          return if modal_win

          # Calculate center position
          center_y = (screen.height - MODAL_HEIGHT) / 2
          center_x = (screen.width - MODAL_WIDTH) / 2

          # Create modal window
          self.modal_win = Window.new(MODAL_HEIGHT, MODAL_WIDTH, center_y, center_x)
        end

        def draw_content
          return unless modal_win

          modal_win.erase
          modal_win.box(0, 0)

          # Header
          modal_win.setpos(1, 2)
          modal_win.attron(color_pair(HEADER_CYAN) | A_BOLD) { modal_win.addstr("🚀 LogBench Update Available!") }

          # Version info
          modal_win.setpos(3, 2)
          modal_win.addstr("Current: ")
          modal_win.attron(color_pair(SUCCESS_GREEN)) { modal_win.addstr(LogBench::VERSION) }
          modal_win.addstr(" → Latest: ")
          modal_win.attron(color_pair(SUCCESS_GREEN) | A_BOLD) { modal_win.addstr(state.update_version) }

          # Instructions with countdown
          modal_win.setpos(5, 2)
          modal_win.addstr("Press any key to continue or wait ")
          modal_win.attron(color_pair(WARNING_YELLOW) | A_BOLD) { modal_win.addstr("#{countdown}s") }
        end

        def update_countdown_timer
          now = Time.now
          if now - last_countdown_update >= 1.0
            self.countdown -= 1
            self.last_countdown_update = now

            if countdown <= 0
              dismiss_modal
            end
          end
        end

        def dismiss_modal
          state.dismiss_update_notification
          modal_win&.close
          self.modal_win = nil
          clear
        end

        def color_pair(n)
          screen.color_pair(n)
        end
      end
    end
  end
end
