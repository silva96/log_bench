# frozen_string_literal: true

module LogBench
  module Log
    class Entry
      attr_reader :type, :raw_line, :request_id, :timestamp, :content, :timing, :json_data

      def initialize(json_data)
        self.json_data = json_data
        self.timestamp = parse_timestamp(json_data["timestamp"])
        self.request_id = json_data["request_id"]
        self.content = json_data["message"] || ""
        self.type = :other
      end

      def http_request?
        type == :http_request
      end

      def related_log?
        !http_request?
      end

      private

      attr_writer :type, :timestamp, :request_id, :content, :timing, :json_data

      def parse_timestamp(timestamp_str)
        return Time.now unless timestamp_str

        Time.parse(timestamp_str)
      rescue ArgumentError
        Time.now
      end
    end
  end
end
