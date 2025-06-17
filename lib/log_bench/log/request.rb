# frozen_string_literal: true

module LogBench
  module Log
    class Request < Entry
      attr_reader :method, :path, :status, :duration, :controller, :action, :params
      attr_accessor :related_logs

      def initialize(raw_line)
        super
        self.related_logs = []
      end

      def self.build(raw_line)
        return unless parseable?(raw_line)

        entry = Entry.new(raw_line)
        return unless entry.http_request?

        new(raw_line)
      end

      def add_related_log(log_entry)
        related_logs << log_entry if log_entry.related_log?
        self.related_logs = related_logs.sort_by(&:timestamp)
      end

      def queries
        related_logs.select { |log| log.is_a?(QueryEntry) }
      end

      def cache_operations
        related_logs.select { |log| log.is_a?(CacheEntry) }
      end

      def query_count
        queries.size
      end

      def total_query_time
        queries.sum(&:duration_ms)
      end

      def cached_query_count
        cache_operations.size
      end

      def success?
        status && status >= 200 && status < 300
      end

      def client_error?
        status && status >= 400 && status < 500
      end

      def server_error?
        status && status >= 500
      end

      def to_h
        super.merge(
          method: method,
          path: path,
          status: status,
          duration: duration,
          controller: controller,
          action: action,
          params: params,
          related_logs: related_logs.map(&:to_h)
        )
      end

      private

      attr_writer :method, :path, :status, :duration, :controller, :action, :params

      def extract_from_json(data)
        return false unless super

        self.method = data["method"]
        self.path = data["path"]
        self.status = data["status"]
        self.duration = data["duration"]
        self.controller = data["controller"]
        self.action = data["action"]
        self.request_id = data["request_id"]
        self.params = parse_params(data["params"])
        true
      end

      def parse_params(params_data)
        return nil unless params_data

        case params_data
        when String
          JSON.parse(params_data)
        when Hash
          params_data
        end
      rescue JSON::ParserError
        params_data.to_s
      end
    end
  end
end
