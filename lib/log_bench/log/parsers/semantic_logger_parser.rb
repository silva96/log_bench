# frozen_string_literal: true

module LogBench
  module Log
    module Parsers
      class SemanticLoggerParser
        TIMESTAMP_PATTERN = /^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)/
        REQUEST_ID_PATTERN = /request_id:\s*([a-f0-9\-]+)/
        DURATION_PATTERN = /\(([0-9.]+)(ms|s)\)/
        COMPLETED_DATA_PATTERN = /--\s+Completed\s+#\w+\s+--\s+\{(.+)\}\s*$/
        RUBY_LOGGER_WRAPPER_PATTERN = /^[A-Z], \[[^\]]+\]\s+[A-Z]+\s+--\s*:\s*/
        ANSI_CODE_PATTERN = /\e\[[0-9;]*m/
        LITERAL_ANSI_PATTERN = /\[[0-9;]*m/

        HUMAN_READABLE_PATTERN_1 = /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+.*?\s+\[.*?\]\s+.*?--\s+/
        HUMAN_READABLE_PATTERN_2 = /^[A-Z], \[.*?\].*?--\s*:\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+/

        LEVEL_MAP = {
          "T" => "trace",
          "D" => "debug",
          "I" => "info",
          "W" => "warn",
          "E" => "error",
          "F" => "fatal"
        }.freeze

        class << self
          def human_readable?(line)
            line.match?(HUMAN_READABLE_PATTERN_1) || line.match?(HUMAN_READABLE_PATTERN_2)
          end

          def convert_to_json(line)
            line = strip_ruby_logger_wrapper(line)

            if line.include?("Completed #")
              convert_completed_request(line)
            else
              convert_basic_log(line)
            end
          rescue ArgumentError, RegexpError => e
            LogBench.logger.debug("Failed to convert SemanticLogger line: #{e.message}") if LogBench.respond_to?(:logger)
            nil
          end

          def strip_ansi_codes(text)
            text.gsub(ANSI_CODE_PATTERN, "").gsub(LITERAL_ANSI_PATTERN, "")
          end

          def strip_ruby_logger_wrapper(line)
            line.sub(RUBY_LOGGER_WRAPPER_PATTERN, "")
          end

          def extract_value_from_hash(hash_str, key)
            hash_str[/(?:#{key}|["']#{key}["'])\s*(?::|=>)\s*["']?([^"',}\s]+)/, 1]
          end

          private

          def convert_basic_log(line)
            match = line.match(/^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(.*?)\s+\[(.*?)\]\s+(\{.*?\}\s+)?(\(.*?\)\s+)?(.*?)\s+--\s+(.+)$/)
            return nil unless match

            timestamp, level_raw, _thread_info, tags_raw, _duration_raw, logger_name_raw, message = match.captures

            json_data = {
              "timestamp" => timestamp,
              "level" => map_level(strip_ansi_codes(level_raw)),
              "name" => strip_ansi_codes(logger_name_raw),
              "message" => strip_ansi_codes(message)
            }

            if tags_raw
              request_id = extract_request_id_from_tags(tags_raw)
              json_data["request_id"] = request_id if request_id
            end

            json_data.to_json
          end

          def convert_completed_request(line)
            timestamp = extract_timestamp(line)
            return nil unless timestamp

            request_data = extract_request_data(line)
            return nil unless request_data[:method] && request_data[:path] && request_data[:status]

            build_json_response(timestamp, request_data)
          end

          def extract_timestamp(line)
            line.match(TIMESTAMP_PATTERN)&.captures&.first
          end

          def extract_request_data(line)
            {
              request_id: extract_request_id_from_tags(line),
              duration: extract_duration(line),
              method: extract_from_completed_hash(line, "method"),
              path: extract_from_completed_hash(line, "path"),
              status: extract_from_completed_hash(line, "status")&.to_i,
              controller: extract_from_completed_hash(line, "controller"),
              action: extract_from_completed_hash(line, "action")
            }
          end

          def extract_request_id_from_tags(line)
            line.match(REQUEST_ID_PATTERN)&.captures&.first
          end

          def extract_duration(line)
            line_no_ansi = strip_ansi_codes(line)
            match = line_no_ansi.match(DURATION_PATTERN)
            return nil unless match

            value = match[1].to_f
            unit = match[2]
            (unit == "s") ? value * 1000.0 : value
          end

          def extract_from_completed_hash(line, key)
            match = line.match(COMPLETED_DATA_PATTERN)
            return nil unless match

            hash_str = "{#{match[1]}}"
            extract_value_from_hash(hash_str, key)
          end

          def build_json_response(timestamp, data)
            {
              "timestamp" => timestamp,
              "level" => "info",
              "name" => data[:controller] || "Rails",
              "message" => "Completed",
              "duration_ms" => data[:duration],
              "payload" => {
                "method" => data[:method],
                "path" => data[:path],
                "status" => data[:status],
                "controller" => data[:controller],
                "action" => data[:action],
                "request_id" => data[:request_id]
              }
            }.to_json
          end

          def map_level(level)
            LEVEL_MAP[level] || level.downcase
          end
        end
      end
    end
  end
end
