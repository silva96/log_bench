# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class Header
        include Curses

        # Application info
        APP_NAME = "LogBench"
        APP_SUBTITLE = "Rails Log Viewer"
        VERSION = "(v#{LogBench::VERSION})"

        # Layout constants
        TITLE_X_OFFSET = 2

        # Color constants
        HEADER_CYAN = 1
        SUCCESS_GREEN = 3

        def initialize(screen, state, log_file_name)
          self.screen = screen
          self.state = state
          self.log_file_name = log_file_name
        end

        def draw
          header_win.erase
          header_win.box(0, 0)

          draw_title
          draw_file_name
          draw_stats
          draw_help_text
        end

        private

        attr_accessor :screen, :state, :log_file_name

        def draw_title
          header_win.setpos(1, TITLE_X_OFFSET)
          header_win.attron(color_pair(HEADER_CYAN) | A_BOLD) { header_win.addstr(APP_NAME) }
          header_win.addstr(" - #{APP_SUBTITLE} #{VERSION}")
        end

        def draw_file_name
          header_win.setpos(1, (screen.width / 2) - (log_file_name.length / 2))
          header_win.attron(color_pair(SUCCESS_GREEN)) { header_win.addstr(log_file_name) }
        end

        def draw_stats
          filtered_requests = state.filtered_requests
          total_requests = state.requests.size

          if state.main_filter.present?
            # Filter active - show "X found (Y total)"
            stats_text = "#{filtered_requests.size} found (#{total_requests} total)"
            header_win.setpos(1, screen.width - stats_text.length - 2)
            header_win.attron(color_pair(3)) { header_win.addstr(filtered_requests.size.to_s) }
            header_win.addstr(" found (")
            header_win.attron(color_pair(3)) { header_win.addstr(total_requests.to_s) }
            header_win.addstr(" total)")
          else
            # No filter active - show simple count
            stats_text = "Requests: #{total_requests}"
            header_win.setpos(1, screen.width - stats_text.length - 2)
            header_win.addstr("Requests: ")
            header_win.attron(color_pair(3)) { header_win.addstr(total_requests.to_s) }
          end
        end

        def draw_help_text
          header_win.setpos(2, 2)
          header_win.attron(A_DIM) do
            header_win.addstr("a:Auto-scroll(")
            header_win.attron(color_pair(3)) { header_win.addstr(state.auto_scroll ? "ON" : "OFF") }
            header_win.addstr(") | f:Filter | c:Clear filter | s:Sort(")
            header_win.attron(color_pair(3)) { header_win.addstr(state.sort.display_name) }
            header_win.addstr(") | t:Text selection(")
            header_win.attron(color_pair(3)) { header_win.addstr(state.text_selection_mode? ? "ON" : "OFF") }
            header_win.addstr(") | q:Quit")
          end

          header_win.setpos(3, 2)
          header_win.attron(A_DIM) do
            header_win.addstr("←→/hl:Pane | ↑↓/jk:Navigate | g/G:Top/End | y:Copy highlighted | Ctrl+L:Clear | Ctrl+R:Restore(")
            header_win.attron(color_pair(3)) { header_win.addstr(state.can_undo_clear? ? "READY" : "N/A") }
            header_win.addstr(")")
          end
        end

        def color_pair(n)
          screen.color_pair(n)
        end

        def header_win
          screen.header_win
        end
      end
    end
  end
end
