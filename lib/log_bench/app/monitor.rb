# frozen_string_literal: true

module LogBench
  module App
    class Monitor
      def initialize(log_file_path, state)
        self.log_file_path = log_file_path
        self.state = state
        self.running = false
      end

      def start
        return if running

        self.running = true
        self.thread = Thread.new { monitor_loop }
      end

      def stop
        self.running = false
        thread&.kill
      end

      private

      attr_accessor :log_file_path, :state, :thread, :running

      def monitor_loop
        log_file = Log::File.new(log_file_path)

        loop do
          break unless running

          begin
            log_file.watch do |new_collection|
              add_new_requests(new_collection.requests)
            end
          rescue
            sleep 1
          end
        end
      end

      def add_new_requests(new_requests)
        return if new_requests.empty?

        state.requests.concat(new_requests)
        keep_recent_requests
      end

      def keep_recent_requests
        # Keep only the last 1000 requests to prevent memory issues
        state.requests = state.requests.last(1000) if state.requests.size > 1000
      end
    end
  end
end
