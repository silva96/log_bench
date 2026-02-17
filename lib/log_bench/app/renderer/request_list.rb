# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class RequestList
        include Curses

        # Layout constants
        HEADER_Y_OFFSET = 2
        COLUMN_HEADER_Y = 1
        FILTER_ROW_Y = 2
        ROWS_START_Y = 3

        # Column widths
        METHOD_WIDTH = 8
        STATUS_WIDTH = 8
        TIME_WIDTH = 6
        STATUS_RENDER_WIDTH = 4
        PATH_MARGIN = 27

        # Color constants
        HEADER_CYAN = Screen::HEADER_CYAN
        DEFAULT_WHITE = Screen::DEFAULT_WHITE
        SUCCESS_GREEN = Screen::SUCCESS_GREEN
        WARNING_YELLOW = Screen::WARNING_YELLOW
        INFO_BLUE = Screen::INFO_BLUE
        ERROR_RED = Screen::ERROR_RED
        SELECTION_HIGHLIGHT = Screen::SELECTION_HIGHLIGHT

        def initialize(screen, state, scrollbar)
          self.screen = screen
          self.state = state
          self.scrollbar = scrollbar
          self.filter_bar = RequestFilterBar.new(
            screen,
            state,
            header_x_offset: HEADER_Y_OFFSET,
            row_y: FILTER_ROW_Y,
            method_width: METHOD_WIDTH
          )
        end

        def draw
          log_win.erase
          log_win.box(0, 0)

          draw_header
          draw_column_headers
          draw_filter_row
          draw_rows
        end

        private

        attr_accessor :screen, :state, :scrollbar, :filter_bar

        def draw_header
          log_win.setpos(0, HEADER_Y_OFFSET)

          if state.left_pane_focused?
            log_win.attron(color_pair(HEADER_CYAN) | A_BOLD) { log_win.addstr(" Request Logs ") }
          else
            log_win.attron(color_pair(DEFAULT_WHITE) | A_DIM) { log_win.addstr(" Request Logs ") }
          end
        end

        def draw_column_headers
          log_win.setpos(COLUMN_HEADER_Y, HEADER_Y_OFFSET)
          log_win.attron(color_pair(HEADER_CYAN) | A_DIM) do
            log_win.addstr(column_header_text("METHOD", :method).ljust(METHOD_WIDTH))
            log_win.addstr("PATH".ljust(path_column_width))
            log_win.addstr(column_header_text("STATUS", :status).ljust(STATUS_WIDTH))
            log_win.addstr(column_header_text("TIME", :time))
          end
        end

        def column_header_text(label, column)
          sort_arrow = state.sort_arrow_for_column(column)
          sort_arrow ? "#{label}#{sort_arrow}" : label
        end

        def draw_filter_row
          filter_bar.draw
        end

        def draw_rows
          filtered_requests = state.filtered_requests
          visible_height = log_win.maxy - 4

          return draw_no_requests_message if filtered_requests.empty?

          state.adjust_auto_scroll(visible_height)
          state.adjust_scroll_bounds(visible_height)

          visible_height.times do |i|
            request_index = state.scroll_offset + i
            break if request_index >= filtered_requests.size

            draw_row(filtered_requests[request_index], request_index, i + ROWS_START_Y)
          end

          # Draw scrollbar if needed
          if filtered_requests.size > visible_height
            scrollbar.draw(log_win, visible_height, state.scroll_offset, filtered_requests.size)
          end
        end

        def draw_no_requests_message
          log_win.setpos(log_win.maxy / 2, 3)
          log_win.attron(A_DIM) { log_win.addstr("No requests found") }
        end

        def draw_row(request, request_index, y_position)
          log_win.setpos(y_position, 1)
          is_selected = request_index == state.selected

          if is_selected
            log_win.attron(color_pair(SELECTION_HIGHLIGHT) | A_DIM) do
              log_win.addstr(" " * (screen.panel_width - 4))
            end
            log_win.setpos(y_position, 1)
          end

          draw_method_badge(request, is_selected)
          draw_path_column(request, is_selected)
          draw_status_column(request, is_selected)
          draw_duration_column(request, is_selected)
        end

        def draw_method_badge(request, is_selected)
          method_text = " #{request.method.ljust(7)} "

          if is_selected
            log_win.attron(color_pair(SELECTION_HIGHLIGHT) | A_DIM) { log_win.addstr(method_text) }
          else
            method_color = method_color_for(request.method)
            log_win.attron(color_pair(method_color) | A_BOLD) { log_win.addstr(method_text) }
          end
        end

        def draw_path_column(request, is_selected)
          path = request.path[0, path_column_width] || ""
          path_width = path_column_width
          path_text = path.ljust(path_width)

          if is_selected
            log_win.attron(color_pair(SELECTION_HIGHLIGHT) | A_DIM) { log_win.addstr(path_text) }
          else
            log_win.addstr(path_text)
          end
        end

        def draw_status_column(request, is_selected)
          return unless request.status

          status_text = "#{request.status.to_s.rjust(3)} "

          log_win.setpos(log_win.cury, status_col_start)
          if is_selected
            log_win.attron(color_pair(SELECTION_HIGHLIGHT) | A_DIM) { log_win.addstr(status_text) }
          else
            status_color = status_color_for(request.status)
            log_win.attron(color_pair(status_color)) { log_win.addstr(status_text) }
          end
        end

        def draw_duration_column(request, is_selected)
          return unless request.duration

          duration_text = "#{request.duration.to_i}ms".ljust(6) + " "

          log_win.setpos(log_win.cury, duration_col_start)
          if is_selected
            log_win.attron(color_pair(SELECTION_HIGHLIGHT) | A_DIM) { log_win.addstr(duration_text) }
          else
            log_win.attron(A_DIM) { log_win.addstr(duration_text) }
          end
        end

        def method_color_for(method)
          case method
          when "GET" then SUCCESS_GREEN
          when "POST" then WARNING_YELLOW
          when "PUT" then INFO_BLUE
          when "DELETE" then ERROR_RED
          else DEFAULT_WHITE
          end
        end

        def status_color_for(status)
          case status
          when 200..299 then SUCCESS_GREEN
          when 300..399 then WARNING_YELLOW
          when 400..599 then ERROR_RED
          else DEFAULT_WHITE
          end
        end

        def path_column_width
          screen.panel_width - PATH_MARGIN
        end

        def status_col_start
          screen.panel_width - 14
        end

        def duration_col_start
          screen.panel_width - 9
        end

        def color_pair(n)
          screen.color_pair(n)
        end

        def log_win
          screen.log_win
        end
      end
    end
  end
end
