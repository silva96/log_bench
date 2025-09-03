# frozen_string_literal: true

module LogBench
  module App
    class Screen
      include Curses

      # Layout constants
      HEADER_HEIGHT = 5
      PANEL_BORDER_WIDTH = 3
      INPUT_TIMEOUT_MS = 200

      # Color pairs
      HEADER_CYAN = 1
      DEFAULT_WHITE = 2
      SUCCESS_GREEN = 3    # GET requests, 200 status
      WARNING_YELLOW = 4   # POST requests, warnings
      INFO_BLUE = 5        # PUT requests
      ERROR_RED = 6        # DELETE requests, errors
      BRIGHT_WHITE = 7
      BLACK = 8
      MAGENTA = 9
      SELECTION_HIGHLIGHT = 10

      attr_reader :header_win, :log_win, :panel_width, :detail_win

      def setup
        init_screen
        setup_colors
        clear_screen_immediately
        setup_windows
        turn_text_selection_mode(false)
      end

      def cleanup
        cleanup_windows
        close_screen
      end

      def refresh_all
        header_win.refresh
        log_win.refresh
        detail_win.refresh
        refresh
      end

      def height
        lines
      end

      def width
        cols
      end

      def color_pair(n)
        Curses.color_pair(n)
      end

      def turn_text_selection_mode(enabled)
        enabled ? mousemask(0) : mousemask(BUTTON1_CLICKED)
      end

      def handle_resize
        # Update terminal dimensions
        resizeterm(0, 0)
        clear
        refresh

        # Recreate windows with new dimensions
        cleanup_windows
        setup_windows
      end

      private

      attr_writer :header_win, :log_win, :panel_width, :detail_win

      def clear_screen_immediately
        clear
        refresh
      end

      def setup_colors
        start_color
        cbreak
        noecho
        curs_set(0)
        stdscr.keypad(true)
        stdscr.timeout = INPUT_TIMEOUT_MS

        # Define color pairs
        init_pair(HEADER_CYAN, COLOR_CYAN, COLOR_BLACK)      # Header/Cyan
        init_pair(DEFAULT_WHITE, COLOR_WHITE, COLOR_BLACK)     # Default/White
        init_pair(SUCCESS_GREEN, COLOR_GREEN, COLOR_BLACK)     # GET/Success/Green
        init_pair(WARNING_YELLOW, COLOR_YELLOW, COLOR_BLACK)    # POST/Warning/Yellow
        init_pair(INFO_BLUE, COLOR_BLUE, COLOR_BLACK)      # PUT/Blue
        init_pair(ERROR_RED, COLOR_RED, COLOR_BLACK)       # DELETE/Error/Red
        init_pair(BRIGHT_WHITE, COLOR_WHITE, COLOR_BLACK)     # Bold/Bright white
        init_pair(BLACK, COLOR_BLACK, COLOR_BLACK)     # Black
        init_pair(MAGENTA, COLOR_MAGENTA, COLOR_BLACK)   # Magenta
        init_pair(SELECTION_HIGHLIGHT, COLOR_BLACK, COLOR_CYAN)     # Selection highlighting
      end

      def cleanup_windows
        header_win&.close
        log_win&.close
        detail_win&.close
      end

      def setup_windows
        self.panel_width = width / 2 - 2

        self.header_win = Window.new(HEADER_HEIGHT, width, 0, 0)
        self.log_win = Window.new(height - HEADER_HEIGHT, panel_width, HEADER_HEIGHT, 0)
        self.detail_win = Window.new(height - HEADER_HEIGHT, width - panel_width - PANEL_BORDER_WIDTH, HEADER_HEIGHT, panel_width + PANEL_BORDER_WIDTH)
      end
    end
  end
end
