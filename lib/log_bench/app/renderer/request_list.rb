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
        FILTER_HINT_TEXT = "Press f to start filtering, operators allowed: > >= < <= 50-100"
        FILTER_RIGHT_EDGE_OFFSET = 2

        # Column widths
        METHOD_WIDTH = 8
        STATUS_WIDTH = 8
        TIME_WIDTH = 6
        STATUS_RENDER_WIDTH = 4
        FILTER_STATUS_WIDTH = 7
        FILTER_TIME_WIDTH = 8
        PATH_MARGIN = 27
        CURSOR_BLINK_INTERVAL_SECONDS = 0.5

        # Color constants
        HEADER_CYAN = Screen::HEADER_CYAN
        DEFAULT_WHITE = Screen::DEFAULT_WHITE
        SUCCESS_GREEN = Screen::SUCCESS_GREEN
        WARNING_YELLOW = Screen::WARNING_YELLOW
        INFO_BLUE = Screen::INFO_BLUE
        ERROR_RED = Screen::ERROR_RED
        SELECTION_HIGHLIGHT = Screen::SELECTION_HIGHLIGHT
        FILTER_CELL_BACKGROUND = Screen::FILTER_CELL_BACKGROUND

        def initialize(screen, state, scrollbar)
          self.screen = screen
          self.state = state
          self.scrollbar = scrollbar
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

        attr_accessor :screen, :state, :scrollbar

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
            log_win.addstr("METHOD".ljust(METHOD_WIDTH))
            log_win.addstr("PATH".ljust(path_column_width))
            log_win.addstr("STATUS".ljust(STATUS_WIDTH))
            log_win.addstr("TIME")
          end
        end

        def draw_filter_row
          if show_filter_cells?
            draw_filter_cells_row
          else
            draw_filter_hint_row
          end
        end

        def show_filter_cells?
          state.filter_mode || state.request_filters_present?
        end

        def draw_filter_hint_row
          log_win.setpos(FILTER_ROW_Y, HEADER_Y_OFFSET)
          consumed = draw_filter_hint_prefix(filter_row_width)
          fill_remaining_filter_row(consumed)
        end

        def draw_filter_hint_prefix(width)
          return 0 if width <= 0

          hint_text = FILTER_HINT_TEXT[0, width].ljust(width)
          log_win.attron(color_pair(DEFAULT_WHITE) | A_DIM) { log_win.addstr(hint_text) }
          hint_text.length
        end

        def fill_remaining_filter_row(consumed_width)
          remaining = filter_row_width - consumed_width
          return if remaining <= 0

          log_win.attron(color_pair(DEFAULT_WHITE) | A_DIM) { log_win.addstr(" " * remaining) }
        end

        def draw_filter_cells_row
          log_win.setpos(FILTER_ROW_Y, HEADER_Y_OFFSET)
          draw_filter_cell(:method, METHOD_WIDTH)
          draw_filter_cell(:path, filter_path_column_width)
          log_win.setpos(FILTER_ROW_Y, status_filter_col_start)
          draw_filter_cell(:status, status_filter_width)
          log_win.setpos(FILTER_ROW_Y, time_filter_col_start)
          draw_filter_cell(:time, time_filter_width)
        end

        def draw_filter_cell(column, width)
          filter_text = filter_text_for(column, width)
          log_win.attron(filter_cell_attributes(column)) { log_win.addstr(filter_text) }
        end

        def filter_text_for(column, width)
          filter = state.request_filter_for(column)
          text = filter.display_text.to_s
          text = "#{text}#{active_filter_cursor}" if active_filter_column?(column)

          align_filter_text(column, text, width)
        end

        def align_filter_text(column, text, width)
          if column == :status
            visible_text = text[0, width]
            visible_text.rjust(width - 1).ljust(width)
          elsif column == :time
            visible_text = text[0, width - 1]
            " #{visible_text}".ljust(width)
          else
            text[0, width].ljust(width)
          end
        end

        def active_filter_column?(column)
          state.filter_mode && state.active_request_filter_column == column
        end

        def filter_cell_attributes(column)
          base = color_pair(FILTER_CELL_BACKGROUND) | A_DIM
          active_filter_column?(column) ? color_pair(FILTER_CELL_BACKGROUND) : base
        end

        def active_filter_cursor
          cursor_visible? ? "█" : " "
        end

        def cursor_visible?
          blink_tick = (Process.clock_gettime(Process::CLOCK_MONOTONIC) / CURSOR_BLINK_INTERVAL_SECONDS).to_i
          blink_tick.even?
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

        def filter_path_column_width
          [status_filter_col_start - (HEADER_Y_OFFSET + METHOD_WIDTH), 1].max
        end

        def status_filter_width
          FILTER_STATUS_WIDTH
        end

        def time_filter_width
          FILTER_TIME_WIDTH
        end

        def filter_row_width
          filter_right_edge - HEADER_Y_OFFSET
        end

        def status_filter_col_start
          time_filter_col_start - status_filter_width
        end

        def time_filter_col_start
          filter_right_edge - time_filter_width
        end

        def filter_right_edge
          screen.panel_width - FILTER_RIGHT_EDGE_OFFSET
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
