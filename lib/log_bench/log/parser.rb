# frozen_string_literal: true

module LogBench
  module Log
    class Parser
      extend JobPrefixFormatter

      def self.parse_line(raw_line)
        clean_line = raw_line.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip

        logger_type = LogBench.configuration&.logger_type || :lograge
        if logger_type == :semantic_logger && Parsers::SemanticLoggerParser.human_readable?(clean_line)
          json_line = Parsers::SemanticLoggerParser.convert_to_json(clean_line)
          clean_line = json_line if json_line
        end

        data = JSON.parse(clean_line)
        return unless data.is_a?(Hash)

        entry = build_specific_entry(data)
        register_job_enqueue(entry)
        enrich_job_entry(entry)
        entry
      rescue JSON::ParserError => e
        LogBench.logger.debug("Failed to parse line as JSON: #{e.message}") if LogBench.respond_to?(:logger)
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
        return :http_request if http_request?(data)
        return :cache if cache_message?(data)
        return :sql if sql_message?(data)
        return :sql_call_line if call_stack_message?(data)
        return :job_enqueue if job_enqueue_message?(data)

        :other
      end

      def self.http_request?(data)
        lograge_request?(data) || semantic_logger_request?(data)
      end

      def self.lograge_request?(data)
        data["method"] && data["path"] && data["status"]
      end

      def self.semantic_logger_request?(data)
        payload = data["payload"]
        return false unless payload.is_a?(Hash)

        payload["method"] && payload["path"] && payload["status"]
      end

      def self.normalize_message(message)
        case message
        when String
          message
        when Array
          message.join(" ")
        when NilClass
          ""
        else
          message.to_s
        end
      end

      def self.sql_message?(data)
        message = normalize_message(data["message"])
        %w[SELECT INSERT UPDATE DELETE TRANSACTION BEGIN COMMIT ROLLBACK SAVEPOINT].any? { |op| message.include?(op) }
      end

      def self.cache_message?(data)
        message = normalize_message(data["message"])
        message.include?("CACHE")
      end

      def self.call_stack_message?(data)
        message = normalize_message(data["message"])
        message.include?("↳")
      end

      def self.job_enqueue_message?(data)
        message = normalize_message(data["message"])
        message.match?(/Enqueued .+ \(Job ID: .+\)/)
      end

      def self.extract_job_id_from_enqueue(message)
        normalized_message = normalize_message(message)
        match = normalized_message.match(/Job ID: ([^\)]+)/)
        match[1] if match
      end

      class << self
        private

        def register_job_enqueue(entry)
          return unless entry.is_a?(JobEnqueueEntry)
          return unless defined?(App::State)

          request_id = entry.request_id

          if !request_id && entry.respond_to?(:json_data)
            tags = entry.json_data["tags"]
            parent_job_id, _parent_job_class = extract_job_info_from_tags(tags)
            request_id = App::State.instance.request_id_for_job(parent_job_id) if parent_job_id
          end

          App::State.instance.register_job_enqueue(entry.job_id, request_id)
        end

        def enrich_job_entry(entry)
          return unless entry.respond_to?(:json_data)

          tags = entry.json_data["tags"]
          job_id, job_class = extract_job_info_from_tags(tags)
          return unless job_id

          add_job_prefix_to_entry(entry, job_id, job_class)
          add_request_id_to_entry(entry, job_id)
        end

        def add_job_prefix_to_entry(entry, job_id, job_class)
          return if entry.content.match?(/\[[\w:]+#[^\]]+\]/)

          job_prefix = build_colored_job_prefix(job_class, job_id)
          new_content = "#{job_prefix} #{entry.content}"
          entry.instance_variable_set(:@content, new_content)
        end

        def add_request_id_to_entry(entry, job_id)
          return if entry.request_id
          return unless defined?(App::State)

          request_id = App::State.instance.request_id_for_job(job_id)
          entry.instance_variable_set(:@request_id, request_id) if request_id
        end
      end
    end
  end
end
