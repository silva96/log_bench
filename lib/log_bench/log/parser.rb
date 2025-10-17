# frozen_string_literal: true

module LogBench
  module Log
    class Parser
      extend JobPrefixFormatter

      def self.parse_line(raw_line)
        clean_line = raw_line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
        data = JSON.parse(clean_line)
        return unless data.is_a?(Hash)

        entry = build_specific_entry(data)
        register_job_enqueue(entry)
        enrich_job_entry(entry)
        entry
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

      # Register job enqueue in State
      def self.register_job_enqueue(entry)
        return unless entry.is_a?(JobEnqueueEntry)
        return unless defined?(App::State)

        App::State.instance.register_job_enqueue(entry.job_id, entry.request_id)
      end

      # Enrich job execution logs with request_id and colored prefix
      def self.enrich_job_entry(entry)
        return unless entry.respond_to?(:json_data)

        tags = entry.json_data["tags"]
        job_id, job_class = extract_job_info_from_tags(tags)
        return unless job_id

        add_job_prefix_to_entry(entry, job_id, job_class)
        add_request_id_to_entry(entry, job_id)
      end

      # Add colored job prefix to entry content
      def self.add_job_prefix_to_entry(entry, job_id, job_class)
        return if entry.content.match?(/\[[\w:]+#[^\]]+\]/)

        job_prefix = build_colored_job_prefix(job_class, job_id)
        new_content = "#{job_prefix} #{entry.content}"
        entry.instance_variable_set(:@content, new_content)
      end

      # Add request_id to entry from State
      def self.add_request_id_to_entry(entry, job_id)
        return if entry.request_id
        return unless defined?(App::State)

        request_id = App::State.instance.request_id_for_job(job_id)
        entry.instance_variable_set(:@request_id, request_id) if request_id
      end
    end
  end
end
