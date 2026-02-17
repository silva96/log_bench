# frozen_string_literal: true

module LogBench
  module Log
    class Entry
      attr_reader :type, :raw_line, :request_id, :timestamp, :content, :timing, :json_data

      def initialize(json_data)
        self.json_data = json_data
        self.timestamp = parse_timestamp(extract_timestamp(json_data))
        # LogStruct uses "req_id", lograge/standard uses "request_id"
        self.request_id = json_data["req_id"] || json_data["request_id"]
        self.content = Parser.normalize_message(extract_message(json_data))
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

      def extract_timestamp(json_data)
        # LogStruct uses "ts", lograge/standard uses "timestamp"
        json_data["ts"] || json_data["timestamp"]
      end

      def extract_message(json_data)
        # LogStruct uses "msg", lograge/standard uses "message"
        json_data["msg"] || json_data["message"]
      end
    end
  end
end
