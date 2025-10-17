# frozen_string_literal: true

require "json"
require "logger"

module LogBench
  # A simple JSON formatter for Rails loggers that creates LogBench-compatible
  # JSON logs. Extends TaggedLogging::Formatter for full Rails compatibility.
  class JsonFormatter < ::Logger::Formatter
    include ActiveSupport::TaggedLogging::Formatter
    include JobPrefixFormatter

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

      # Get job info from Current attributes (direct Sidekiq jobs) or tags (ActiveJob)
      job_id, job_class = get_job_info(tags)

      # Add colored job prefix to message if we're in a job context
      if job_id && job_class && entry[:message]
        job_prefix = build_colored_job_prefix(job_class, job_id)
        entry[:message] = "#{job_prefix} #{entry[:message]}"
      end

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
      get_current_attribute(:request_id)
    end

    def current_jid
      get_current_attribute(:jid)
    end

    def current_job_class
      get_current_attribute(:job_class)
    end

    # Generic method to get current attributes from various storage mechanisms
    def get_current_attribute(attribute_name)
      # Try LogBench::Current first (preferred)
      if defined?(LogBench::Current) && LogBench::Current.respond_to?(attribute_name)
        return LogBench::Current.public_send(attribute_name)
      end

      # Try Current (fallback for apps that define their own Current)
      if defined?(Current) && Current.respond_to?(attribute_name)
        return Current.public_send(attribute_name)
      end

      # Try RequestStore (for apps using request_store gem)
      if defined?(RequestStore) && RequestStore.exist?(attribute_name)
        return RequestStore.read(attribute_name)
      end

      # Try Thread local storage (last resort)
      Thread.current[attribute_name]
    end

    # Get job info from Current attributes (direct Sidekiq jobs) or tags (ActiveJob)
    def get_job_info(tags)
      # First try Current attributes (for direct Sidekiq jobs)
      current_jid = get_current_attribute(:jid)
      current_job_class = get_current_attribute(:job_class)

      if current_jid && current_job_class
        return [current_jid, current_job_class]
      end

      # Fallback to tags (for ActiveJob)
      extract_job_info_from_tags(tags)
    end
  end
end
