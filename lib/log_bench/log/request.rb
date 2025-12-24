# frozen_string_literal: true

module LogBench
  module Log
    class Request < Entry
      attr_reader :method, :path, :status, :duration, :controller, :action, :params, :related_logs, :orphan

      def initialize(json_data, orphan: false)
        super(json_data)
        self.type = :http_request
        self.related_logs = []

        # Extract fields from either top-level (lograge) or payload (semantic_logger)
        source = json_data["payload"] || json_data

        self.method = source["method"]
        self.path = source["path"]
        self.status = source["status"]
        self.duration = extract_duration(json_data, source)
        self.controller = source["controller"]
        self.action = source["action"]
        self.params = parse_params(source["params"])
        self.orphan = orphan
      end

      def self.new_orphan(request_id)
        new({"request_id" => request_id}, orphan: true)
      end

      def add_related_log(log_entry)
        if log_entry.related_log?
          related_logs << log_entry
          clear_memoized_values
        end
      end

      def queries
        @queries ||= related_logs.select { |log| log.is_a?(QueryEntry) }
      end

      def cache_operations
        @cache_operations ||= related_logs.select { |log| log.is_a?(QueryEntry) && log.cached? }
      end

      def sql_queries
        @sql_queries ||= related_logs.select { |log| log.is_a?(QueryEntry) && !log.cached? }
      end

      def query_count
        @query_count ||= queries.size
      end

      def total_query_time
        @total_query_time ||= queries.sum(&:duration_ms)
      end

      def cached_query_count
        @cached_query_count ||= cache_operations.size
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

      private

      attr_writer :method, :path, :status, :duration, :controller, :action, :params, :orphan

      def related_logs=(value)
        @related_logs = value
        clear_memoized_values
      end

      def clear_memoized_values
        @queries = nil
        @cache_operations = nil
        @query_count = nil
        @total_query_time = nil
        @cached_query_count = nil
      end

      def extract_duration(json_data, source)
        # SemanticLogger uses duration_ms at top level, lograge uses duration in source
        json_data["duration_ms"] || source["duration"]
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
