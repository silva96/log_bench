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

      def initialize(json_data, cached: false)
        super(json_data)
        self.type = cached ? :cache : :sql
        self.timing = extract_timing
        self.operation = extract_operation
      end

      def duration_ms
        @duration_ms ||= calculate_duration_ms
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

      def cached?
        type == :cache
      end

      def hit?
        cached? && content.include?("CACHE")
      end

      private

      attr_accessor :operation, :cached

      def extract_timing
        match = clean_content.match(/\(([0-9.]+ms)\)/)
        match ? match[1] : nil
      end

      def extract_operation
        SQL_OPERATIONS.find { |op| clean_content.include?(op) }
      end

      def clean_content
        @clean_content ||= content&.gsub(/\e\[[0-9;]*m/, "") || ""
      end

      def has_ansi_codes?
        @has_ansi_codes ||= content&.match?(/\e\[[0-9;]*m/) || false
      end

      def calculate_duration_ms
        return 0.0 unless timing

        timing.gsub(/[()ms]/, "").to_f
      end

      def clear_memoized_values
        @duration_ms = nil
        @clean_content = nil
        @has_ansi_codes = nil
      end

      def content=(value)
        super
        clear_memoized_values
      end

      def timing=(value)
        super
        clear_memoized_values
      end
    end
  end
end
