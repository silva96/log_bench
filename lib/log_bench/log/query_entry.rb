# frozen_string_literal: true

module LogBench
  module Log
    class QueryEntry < Entry
      SELECT = "SELECT"
      INSERT = "INSERT"
      UPDATE = "UPDATE"
      DELETE = "DELETE"
      TRANSACTION = "TRANSACTION"
      BEGIN_TRANSACTION = "BEGIN"
      COMMIT = "COMMIT"
      ROLLBACK = "ROLLBACK"
      SAVEPOINT = "SAVEPOINT"
      SQL_OPERATIONS = [SELECT, INSERT, UPDATE, DELETE, TRANSACTION, BEGIN_TRANSACTION, COMMIT, ROLLBACK, SAVEPOINT].freeze

      def initialize(raw_line)
        super
        self.type = :sql
      end

      def self.build(raw_line)
        return unless parseable?(raw_line)

        entry = Entry.new(raw_line)
        return unless entry.type == :sql

        new(raw_line)
      end

      def duration_ms
        return 0.0 unless timing

        timing.gsub(/[()ms]/, "").to_f
      end

      def select?
        operation == SELECT
      end

      def insert?
        operation == INSERT
      end

      def update?
        operation == UPDATE
      end

      def delete?
        operation == DELETE
      end

      def transaction?
        operation == TRANSACTION
      end

      def begin?
        operation == BEGIN_TRANSACTION
      end

      def commit?
        operation == COMMIT
      end

      def rollback?
        operation == ROLLBACK
      end

      def savepoint?
        operation == SAVEPOINT
      end

      def slow?(threshold_ms = 100)
        duration_ms > threshold_ms
      end

      def to_h
        super.merge(
          content: content,
          timing: timing,
          operation: operation,
          duration_ms: duration_ms,
          has_ansi: has_ansi_codes?(content)
        )
      end

      private

      def extract_from_json(data)
        # Call parent method which checks for request_id
        return false unless super

        message = data["message"] || ""
        return false unless sql_message?(data)

        self.content = message.strip
        extract_timing_and_operation
        true
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

      def has_ansi_codes?(text)
        text.match?(/\e\[[0-9;]*m/)
      end

      private

      attr_accessor :operation
    end
  end
end
