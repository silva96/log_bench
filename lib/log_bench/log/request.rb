# frozen_string_literal: true

module LogBench
  module Log
    class Request < Entry
      attr_reader :method, :path, :status, :duration, :controller, :action, :params, :related_logs

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

      attr_writer :method, :path, :status, :duration, :controller, :action, :params

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
