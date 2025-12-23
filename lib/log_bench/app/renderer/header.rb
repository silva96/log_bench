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
          if state.main_filter.present?
            draw_filtered_stats
          else
            draw_stats_panel
          end
        end

        def draw_filtered_stats
          # When filter is active, show compact "X found (Y total)" on line 1
          filtered_requests = state.filtered_requests
          total_requests = state.requests.size
          stats_text = "#{filtered_requests.size} found (#{total_requests} total)"
          header_win.setpos(1, screen.width - stats_text.length - 2)
          header_win.attron(color_pair(3)) { header_win.addstr(filtered_requests.size.to_s) }
          header_win.addstr(" found (")
          header_win.attron(color_pair(3)) { header_win.addstr(total_requests.to_s) }
          header_win.addstr(" total)")
        end

        def draw_stats_panel
          # Calculate stats
          total_requests = state.requests.size
          total_queries = state.total_queries
          req_per_sec = state.requests_per_second
          req_per_min = state.requests_per_minute
          queries_per_sec = state.queries_per_second
          queries_per_min = state.queries_per_minute

          # Calculate width for alignment
          header_text = "        Total | sec | min"
          max_width = header_text.length
          start_x = screen.width - max_width - 2

          # Draw header line (dimmed)
          header_win.setpos(1, start_x)
          header_win.attron(A_DIM) { header_win.addstr(header_text) }

          # Draw requests line
          header_win.setpos(2, start_x)
          draw_stats_line("Req:   ", total_requests, req_per_sec, req_per_min)

          # Draw queries line
          header_win.setpos(3, start_x)
          draw_stats_line("Query: ", total_queries, queries_per_sec, queries_per_min)
        end

        def draw_stats_line(label, total, per_sec, per_min)
          # Draw label
          header_win.addstr(label)

          # Draw total (highlighted, right-aligned in 6 chars)
          total_str = format("%6d", total)
          header_win.attron(color_pair(SUCCESS_GREEN)) { header_win.addstr(total_str) }
          header_win.addstr(" | ")

          # Draw per second (highlighted, right-aligned in 3 chars)
          per_sec_str = format("%3.0f", per_sec)
          header_win.attron(color_pair(SUCCESS_GREEN)) { header_win.addstr(per_sec_str) }
          header_win.addstr(" | ")

          # Draw per minute (highlighted, right-aligned in 3 chars)
          per_min_str = format("%3.0f", per_min)
          header_win.attron(color_pair(SUCCESS_GREEN)) { header_win.addstr(per_min_str) }
        end

        def draw_help_text
          header_win.setpos(2, 2)
          header_win.attron(A_DIM) do
            help_line_1 = "a:Auto-scroll("
            header_win.addstr(help_line_1)
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
