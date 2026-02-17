# frozen_string_literal: true

module LogBench
  module App
    module Renderer
      class RequestFilterBar
        include Curses

        FILTER_HINT_TEXT = "Press f to start filtering, operators allowed: > >= < <= 50-100"
        FILTER_RIGHT_EDGE_OFFSET = 2
        FILTER_STATUS_WIDTH = 7
        FILTER_TIME_WIDTH = 8
        CURSOR_BLINK_INTERVAL_SECONDS = 0.5

        DEFAULT_WHITE = Screen::DEFAULT_WHITE
        FILTER_CELL_BACKGROUND = Screen::FILTER_CELL_BACKGROUND

        def initialize(screen, state, header_x_offset:, row_y:, method_width:)
          self.screen = screen
          self.state = state
          self.header_x_offset = header_x_offset
          self.row_y = row_y
          self.method_width = method_width
        end

        def draw
          if show_filter_cells?
            draw_filter_cells_row
          else
            draw_filter_hint_row
          end
        end

        def self.layout(panel_width, header_x_offset:, method_width:)
          filter_right_edge = panel_width - FILTER_RIGHT_EDGE_OFFSET
          time_start = filter_right_edge - FILTER_TIME_WIDTH
          status_start = time_start - FILTER_STATUS_WIDTH
          path_start = header_x_offset + method_width
          path_width = [status_start - path_start, 1].max

          {
            method: (header_x_offset...(header_x_offset + method_width)),
            path: (path_start...(path_start + path_width)),
            status: (status_start...(status_start + FILTER_STATUS_WIDTH)),
            time: (time_start...(time_start + FILTER_TIME_WIDTH)),
            path_width: path_width,
            status_start: status_start,
            time_start: time_start,
            filter_right_edge: filter_right_edge
          }
        end

        private

        attr_accessor :screen, :state, :header_x_offset, :row_y, :method_width

        def show_filter_cells?
          state.filter_mode || state.request_filters_present?
        end

        def draw_filter_hint_row
          log_win.setpos(row_y, header_x_offset)
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
          current_layout = layout

          log_win.setpos(row_y, header_x_offset)
          draw_filter_cell(:method, method_width)
          draw_filter_cell(:path, current_layout[:path_width])

          log_win.setpos(row_y, current_layout[:status_start])
          draw_filter_cell(:status, FILTER_STATUS_WIDTH)

          log_win.setpos(row_y, current_layout[:time_start])
          draw_filter_cell(:time, FILTER_TIME_WIDTH)
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

        def layout
          self.class.layout(
            screen.panel_width,
            header_x_offset: header_x_offset,
            method_width: method_width
          )
        end

        def filter_row_width
          layout[:filter_right_edge] - header_x_offset
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
