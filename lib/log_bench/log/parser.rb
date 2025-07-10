# frozen_string_literal: true

module LogBench
  module Log
    class Parser
      def self.parse_line(raw_line)
        return unless Entry.parseable?(raw_line)

        entry = Entry.new(raw_line)
        build_specific_entry(entry)
      end

      def self.parse_lines(lines)
        lines.map { |line| parse_line(line) }.compact
      end

      def self.group_by_request(entries)
        grouped = entries.group_by(&:request_id)
        build_requests_from_groups(grouped)
      end

      def self.build_specific_entry(entry)
        case entry.type
        when :http_request
          Request.build(entry.raw_line)
        when :sql, :cache
          QueryEntry.build(entry.raw_line)
        when :sql_call_line
          CallLineEntry.build(entry.raw_line)
        else
          entry
        end
      end

      def self.build_requests_from_groups(grouped)
        requests = []

        grouped.each do |request_id, entries|
          next unless request_id

          request = find_request_entry(entries)
          next unless request

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
    end
  end
end
