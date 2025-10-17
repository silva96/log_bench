# frozen_string_literal: true

module LogBench
  module Log
    class Parser
      extend JobPrefixFormatter
      def self.parse_line(raw_line)
        clean_line = raw_line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
        data = JSON.parse(clean_line)
        return unless data.is_a?(Hash)

        build_specific_entry(data)
      rescue JSON::ParserError
        nil
      end

      def self.parse_lines(lines, job_ids_map = {})
        lines.map { |line| parse_line(line) }.compact
      end

      def self.group_by_request(entries, job_ids_map = {})
        # Enrich entries with request_ids from job mapping BEFORE grouping
        enriched_entries = enrich_entries_with_request_ids(entries, job_ids_map)
        grouped = enriched_entries.group_by(&:request_id)
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
        when :job_enqueue
          JobEnqueueEntry.new(data)
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
        return :job_enqueue if job_enqueue_message?(data)

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

      def self.job_enqueue_message?(data)
        message = data["message"] || ""
        message.match?(/Enqueued .+ \(Job ID: .+\)/)
      end

      def self.extract_job_id_from_enqueue(message)
        match = message.match(/Job ID: ([^\)]+)/)
        match[1] if match
      end

      def self.extract_job_id_from_tags(tags)
        return nil unless tags.is_a?(Array) && tags.size >= 3

        # ActiveJob tags format: ["ActiveJob", "JobClassName", "job-id"]
        if tags[0] == "ActiveJob" && tags[2]
          tags[2]
        end
      end

      def self.enrich_entries_with_request_ids(entries, job_ids_map)
        entries.each do |entry|
          next unless entry.respond_to?(:json_data)

          tags = entry.json_data["tags"]
          job_id, job_class = extract_job_info_from_tags(tags)
          next unless job_id

          # Add colored job prefix if message doesn't already have one
          # (This works for both old logs and new logs)
          add_job_prefix_to_entry(entry, job_id, job_class)

          # Enrich with request_id if entry doesn't have one
          if !entry.request_id && !job_ids_map.empty?
            request_id = job_ids_map[job_id]
            entry.instance_variable_set(:@request_id, request_id) if request_id
          end
        end

        entries
      end

      def self.add_job_prefix_to_entry(entry, job_id, job_class)
        # Check if message already has a job prefix (colored or not)
        return if entry.content.match?(/\[[\w:]+#[^\]]+\]/)

        # Build colored job prefix
        job_prefix = build_colored_job_prefix(job_class, job_id)
        new_content = "#{job_prefix} #{entry.content}"

        # Update the entry's content
        entry.instance_variable_set(:@content, new_content)
      end

    end
  end
end
