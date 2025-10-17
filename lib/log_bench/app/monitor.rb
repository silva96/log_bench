# frozen_string_literal: true

module LogBench
  module App
    class Monitor
      def initialize(log_file, state)
        self.log_file = log_file
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

      attr_accessor :log_file, :state, :thread, :running

      def monitor_loop
        loop do
          break unless running

          begin
            log_file.watch do |new_collection|
              add_new_requests(new_collection.requests)
              add_orphan_requests(new_collection.orphan_requests)
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

      def add_orphan_requests(orphan_requests)
        state.orphan_requests.concat(orphan_requests)
        return if state.orphan_requests.empty?

        # Try to attach orphaned logs to existing requests and remove them if successful
        state.orphan_requests.reject! do |orphan_request|
          request = state.requests.find { |req| req.request_id == orphan_request.request_id }

          if request
            orphan_request.related_logs.each { |log| request.add_related_log(log) }
            true # Remove this orphan request from the list
          else
            false # Keep this orphan request for later
          end
        end
      end

      def keep_recent_requests
        # Keep only the last 1000 requests to prevent memory issues
        state.requests = state.requests.last(1000) if state.requests.size > 1000
      end
    end
  end
end
