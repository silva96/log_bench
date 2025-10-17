# frozen_string_literal: true

module LogBench
  module Log
    class File
      INACTIVE_SLEEP_TIME = 0.5
      ACTIVE_SLEEP_TIME = 0.01

      def initialize(path)
        self.path = find_log_file(path)
        self.last_position = 0
        validate!
      end

      def requests
        collection.requests
      end

      def watch
        loop do
          new_lines = read_new_lines

          if new_lines.empty?
            sleep INACTIVE_SLEEP_TIME
            next
          end

          new_collection = Collection.new(new_lines)
          yield new_collection unless new_collection.empty?

          sleep ACTIVE_SLEEP_TIME
        end
      end

      def mark_as_read!
        self.last_position = size
      end

      private

      attr_accessor :path, :last_position

      def collection
        @collection ||= Collection.new(lines)
      end

      def lines
        @lines ||= read_lines
      end

      def size
        ::File.size(path)
      end

      def exist?
        ::File.exist?(path)
      end

      def read_lines
        return [] unless exist?

        ::File.readlines(path, chomp: true)
      end

      def read_new_lines
        return [] unless exist?
        return [] unless size > last_position

        new_lines = []
        ::File.open(path, "r") do |file|
          file.seek(last_position)
          new_lines = file.readlines(chomp: true)
          self.last_position = file.tell
        end

        new_lines
      end

      def find_log_file(path)
        candidates = [path, "log/development.log"]

        candidates.find { |candidate| ::File.exist?(candidate) } || path
      end

      def validate!
        raise Error, "File not found: #{path}" unless exist?
      end
    end
  end
end
