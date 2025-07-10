# frozen_string_literal: true

module LogBench
  module Log
    class Entry
      attr_reader :type, :raw_line, :request_id, :timestamp, :content, :timing

      def initialize(raw_line)
        self.raw_line = raw_line.strip
        self.timestamp = Time.now
        self.type = :unknown
        parse!
      end

      def self.build(raw_line)
        new(raw_line) if parseable?(raw_line)
      end

      def self.parseable?(line)
        data = JSON.parse(line.strip)
        data.is_a?(Hash)
      rescue JSON::ParserError
        false
      end

      def http_request?
        type == :http_request
      end

      def related_log?
        !http_request?
      end

      private

      attr_writer :type, :raw_line, :timestamp, :request_id, :content, :timing

      def parse!
        parse_json
      end

      def parse_json
        data = JSON.parse(raw_line)
        return false unless data.is_a?(Hash)

        # extract_from_json returns false if log should be discarded
        extract_from_json(data)
      rescue JSON::ParserError
        false
      end

      def extract_from_json(data)
        # Discard logs without request_id - they can't be correlated
        return false unless data["request_id"]

        self.timestamp = parse_timestamp(data["timestamp"])
        self.request_id = data["request_id"]
        self.content = data["message"]
        self.type = determine_json_type(data)
        true
      end

      def determine_json_type(data)
        return :http_request if lograge_request?(data)
        return :cache if cache_message?(data)
        return :sql if sql_message?(data)
        return :sql_call_line if call_stack_message?(data)

        :other
      end

      def lograge_request?(data)
        data["method"] && data["path"] && data["status"]
      end

      def sql_message?(data)
        message = data["message"] || ""
        %w[SELECT INSERT UPDATE DELETE TRANSACTION BEGIN COMMIT ROLLBACK SAVEPOINT].any? { |op| message.include?(op) }
      end

      def cache_message?(data)
        message = data["message"] || ""
        message.include?("CACHE")
      end

      def call_stack_message?(data)
        message = data["message"] || ""
        message.include?("↳")
      end

      def parse_timestamp(timestamp_str)
        return Time.now unless timestamp_str

        Time.parse(timestamp_str)
      rescue ArgumentError
        Time.now
      end
    end
  end
end
