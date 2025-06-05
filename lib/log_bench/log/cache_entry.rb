# frozen_string_literal: true

module LogBench
  module Log
    class CacheEntry < Entry
      SQL_OPERATIONS = %w[SELECT INSERT UPDATE DELETE].freeze

      attr_reader :content, :timing

      def initialize(raw_line)
        super
        self.type = :cache
      end

      def self.build(raw_line)
        return unless parseable?(raw_line)

        entry = Entry.new(raw_line)
        return unless entry.type == :cache

        new(raw_line)
      end

      def duration_ms
        return 0.0 unless timing

        timing.gsub(/[()ms]/, "").to_f
      end

      def hit?
        content.include?("CACHE")
      end

      def miss?
        !hit?
      end

      def to_h
        super.merge(
          content: content,
          timing: timing,
          operation: operation,
          duration_ms: duration_ms,
          hit: hit?
        )
      end

      private

      attr_reader :operation
      attr_writer :content, :timing, :operation

      def extract_from_json(data)
        super
        message = data["message"] || ""
        return unless cache_message?(data)

        self.content = message.strip
        extract_timing_and_operation
      end

      def extract_timing_and_operation
        clean_content = remove_ansi_codes(content)
        self.timing = extract_timing(clean_content)
        self.operation = extract_operation(clean_content)
      end

      def extract_timing(text)
        match = text.match(/\(([0-9.]+ms)\)/)
        match ? match[1] : nil
      end

      def extract_operation(text)
        SQL_OPERATIONS.find { |op| text.include?(op) }
      end

      def remove_ansi_codes(text)
        text.gsub(/\e\[[0-9;]*m/, "")
      end
    end
  end
end
