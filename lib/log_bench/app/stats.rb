# frozen_string_literal: true

module LogBench
  module App
    class Stats
      def initialize
        self.request_history = []
        self.last_calculation_time = Time.now
        self.cached_requests_per_sec = 0.0
        self.cached_requests_per_min = 0.0
        self.cached_queries_per_sec = 0.0
        self.cached_queries_per_min = 0.0
      end

      def track_requests(new_requests)
        return if new_requests.empty?

        now = Time.now
        new_requests.each do |req|
          request_history << {time: now, queries: req.query_count}
        end
      end

      def requests_per_second
        update_calculations
        cached_requests_per_sec
      end

      def requests_per_minute
        update_calculations
        cached_requests_per_min
      end

      def queries_per_second
        update_calculations
        cached_queries_per_sec
      end

      def queries_per_minute
        update_calculations
        cached_queries_per_min
      end

      private

      attr_accessor :request_history, :last_calculation_time
      attr_accessor :cached_requests_per_sec, :cached_requests_per_min
      attr_accessor :cached_queries_per_sec, :cached_queries_per_min

      # Update rate calculations based on recent activity using rolling buffer
      # We calculate per-second rate from last 1 second, per-minute rate from last 60 seconds
      def update_calculations
        now = Time.now

        # Only recalculate every 0.5 seconds to avoid excessive computation
        return if now - last_calculation_time < 0.5

        self.last_calculation_time = now

        # Remove entries older than 60 seconds (we only need last 60 seconds)
        cutoff_time = now - 60.0
        request_history.reject! { |entry| entry[:time] < cutoff_time }

        # Count requests and queries in the last 1 second
        one_sec_cutoff = now - 1.0
        last_sec_entries = request_history.select { |entry| entry[:time] > one_sec_cutoff }
        last_sec_count = last_sec_entries.size
        last_sec_queries = last_sec_entries.sum { |entry| entry[:queries] }

        # Count requests and queries in the last 60 seconds (all remaining entries)
        last_min_count = request_history.size
        last_min_queries = request_history.sum { |entry| entry[:queries] }

        # Per-second rate: count from last 1 second
        self.cached_requests_per_sec = last_sec_count.to_f
        self.cached_queries_per_sec = last_sec_queries.to_f

        # Per-minute rate: count from last 60 seconds
        self.cached_requests_per_min = last_min_count.to_f
        self.cached_queries_per_min = last_min_queries.to_f
      end
    end
  end
end

