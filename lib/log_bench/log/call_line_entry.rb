# frozen_string_literal: true

module LogBench
  module Log
    class CallLineEntry < Entry
      def initialize(raw_line)
        super
        self.type = :sql_call_line
      end

      def self.build(raw_line)
        return unless parseable?(raw_line)

        entry = Entry.new(raw_line)
        return unless entry.type == :sql_call_line

        new(raw_line)
      end

      private

      attr_accessor :file_path, :line_number, :method_name

      def extract_from_json(data)
        super
        message = Parser.normalize_message(data["message"])
        return unless call_line_message?(data)

        self.content = message.strip
        extract_call_info
      end

      def extract_call_info
        # Parse call line like "  ↳ app/controllers/users_controller.rb:10:in 'UsersController#show'"
        if content =~ /↳\s+(.+):(\d+):in\s+'(.+)'/
          self.file_path = $1
          self.line_number = $2.to_i
          self.method_name = $3
        end
      end

      def call_line_message?(data)
        message = Parser.normalize_message(data["message"])
        message.include?("↳")
      end
    end
  end
end
