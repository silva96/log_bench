# frozen_string_literal: true

require "curses"

module LogBench
  module App
    class Main
      include Curses

      # Default log file paths
      DEFAULT_LOG_PATHS = %w[log/development.log].freeze

      # Timing
      MAIN_LOOP_SLEEP_INTERVAL = 1.0 / 1000 # 1ms

      # Error messages
      LOG_FILE_NOT_FOUND = "Error: No log file found at %s!"
      RAILS_PROJECT_HINT = "Please run from a Rails project directory or specify a valid log file"

      def initialize(log_file_path = "log/development.log")
        self.log_file_path = find_log_file(log_file_path)
        self.state = State.instance
        validate_log_file!
      end

      def run
        setup_screen
        setup_components
        load_initial_data
        check_for_updates
        initial_draw
        start_monitoring
        main_loop
      ensure
        cleanup
      end

      private

      attr_accessor :log_file_path, :log_file, :state, :screen, :monitor, :input_handler, :renderer

      def find_log_file(path)
        candidates = [path] + DEFAULT_LOG_PATHS
        candidates.find { |candidate| File.exist?(candidate) } || path
      end

      def validate_log_file!
        unless File.exist?(log_file_path)
          puts LOG_FILE_NOT_FOUND % log_file_path
          puts RAILS_PROJECT_HINT
          exit 1
        end
      end

      def log_file_name
        File.basename(log_file_path)
      end

      def setup_screen
        self.screen = Screen.new
        screen.setup
      end

      def setup_components
        self.renderer = Renderer::Main.new(screen, state, log_file_name)
        self.input_handler = InputHandler.new(state, screen, renderer)
      end

      def load_initial_data
        self.log_file = Log::File.new(log_file_path)
        state.requests = log_file.requests
        log_file.mark_as_read!
      end

      def check_for_updates
        latest_version = VersionChecker.check_for_update
        state.set_update_available(latest_version) if latest_version
      end

      def initial_draw
        renderer.draw
      end

      def start_monitoring
        self.monitor = Monitor.new(log_file, state)
        monitor.start
      end

      def main_loop
        loop do
          break unless state.running?

          renderer.draw
          input_handler.handle_input
          sleep MAIN_LOOP_SLEEP_INTERVAL
        end
      end

      def cleanup
        monitor&.stop
        screen&.cleanup
      end
    end
  end
end
