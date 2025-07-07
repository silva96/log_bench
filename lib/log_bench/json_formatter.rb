# frozen_string_literal: true

require "json"
require "logger"

module LogBench
  # A simple JSON formatter for Rails loggers that creates LogBench-compatible
  # JSON logs. Extends TaggedLogging::Formatter for full Rails compatibility.
  class JsonFormatter < ::Logger::Formatter
    include ActiveSupport::TaggedLogging::Formatter

    def call(severity, timestamp, progname, message)
      log_entry = build_log_entry(severity, timestamp, progname, message)
      log_entry.to_json + "\n"
    rescue
      # Fallback to simple format if JSON generation fails
      "#{timestamp} [#{severity}] #{progname}: #{message}\n"
    end

    private

    def build_log_entry(severity, timestamp, progname, message)
      entry = message_to_hash(message)
      tags = current_tags
      entry = parse_lograge_message(entry[:message]) if lograge_message?(entry)
      request_id = current_request_id

      base_entry = {
        level: severity,
        timestamp: timestamp.utc.iso8601(3),
        time: timestamp.to_f,
        request_id: request_id,
        progname: progname
      }

      # Add tags if present
      base_entry[:tags] = tags if tags.any?

      entry.merge!(base_entry).compact
    end

    def message_to_hash(message)
      case message
      when String
        {message: message}
      when Hash
        message.dup
      when Exception
        {
          message: "#{message.class}: #{message.message}",
          error_class: message.class.name,
          error_message: message.message
        }
      else
        {message: message.to_s}
      end
    end

    def lograge_message?(entry)
      return false unless entry[:message].is_a?(String) && entry[:message].start_with?("{")

      begin
        parsed = JSON.parse(entry[:message])
        parsed.is_a?(Hash) && parsed["method"] && parsed["path"] && parsed["status"]
      rescue JSON::ParserError
        false
      end
    end

    def parse_lograge_message(message_string)
      JSON.parse(message_string)
    rescue JSON::ParserError
      nil
    end

    def current_request_id
      request_id = nil

      if defined?(LogBench::Current) && LogBench::Current.respond_to?(:request_id)
        request_id = LogBench::Current.request_id
      elsif defined?(Current) && Current.respond_to?(:request_id)
        request_id = Current.request_id
      elsif defined?(RequestStore) && RequestStore.exist?(:request_id)
        request_id = RequestStore.read(:request_id)
      elsif Thread.current[:request_id]
        request_id = Thread.current[:request_id]
      end

      request_id
    end
  end
end
