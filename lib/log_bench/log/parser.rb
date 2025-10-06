# frozen_string_literal: true

module LogBench
  module Log
    class Parser
      def self.parse_line(raw_line)
        clean_line = raw_line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
        data = JSON.parse(clean_line)
        return unless data.is_a?(Hash)

        build_specific_entry(data)
      rescue JSON::ParserError
        nil
      end

      def self.parse_lines(lines)
        lines.map { |line| parse_line(line) }.compact
      end

      def self.group_by_request(entries)
        grouped = entries.group_by(&:request_id)
        build_requests_from_groups(grouped)
      end

      def self.build_specific_entry(data)
        case determine_json_type(data)
        when :http_request
          Request.new(data)
        when :sql
          QueryEntry.new(data, cached: false)
        when :cache
          QueryEntry.new(data, cached: true)
        when :sql_call_line
          CallLineEntry.new(data)
        else
          Entry.new(data)
        end
      end

      def self.build_requests_from_groups(grouped)
        requests = []

        grouped.each do |request_id, entries|
          next unless request_id

          request = find_request_entry(entries) || Request.new_orphan(request_id)

          related_logs = find_related_logs(entries)
          related_logs.each { |log| request.add_related_log(log) }

          requests << request
        end

        requests.sort_by(&:timestamp)
      end

      def self.find_request_entry(entries)
        entries.find { |entry| entry.is_a?(Request) }
      end

      def self.find_related_logs(entries)
        entries.reject { |entry| entry.is_a?(Request) }
      end

      def self.determine_json_type(data)
        return :http_request if lograge_request?(data)
        return :cache if cache_message?(data)
        return :sql if sql_message?(data)
        return :sql_call_line if call_stack_message?(data)

        :other
      end

      def self.lograge_request?(data)
        data["method"] && data["path"] && data["status"]
      end

      def self.sql_message?(data)
        message = data["message"] || ""
        %w[SELECT INSERT UPDATE DELETE TRANSACTION BEGIN COMMIT ROLLBACK SAVEPOINT].any? { |op| message.include?(op) }
      end

      def self.cache_message?(data)
        message = data["message"] || ""
        message.include?("CACHE")
      end

      def self.call_stack_message?(data)
        message = data["message"] || ""
        message.include?("↳")
      end
    end
  end
end
