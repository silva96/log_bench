# frozen_string_literal: true

module LogBench
  module Log
    class File
      attr_reader :path, :last_position

      def initialize(path)
        self.path = find_log_file(path)
        self.last_position = 0
        validate!
      end

      def requests
        collection.requests
      end

      def entries
        collection.entries
      end

      def collection
        @collection ||= Collection.new(lines)
      end

      def lines
        @lines ||= read_lines
      end

      def reload!
        self.lines = nil
        self.collection = nil
        self.last_position = 0
      end

      def tail(max_lines = 1000)
        all_lines = read_lines
        recent_lines = all_lines.last(max_lines)
        Collection.new(recent_lines)
      end

      def watch(&block)
        return enum_for(:watch) unless block_given?

        loop do
          new_lines = read_new_lines
          next if new_lines.empty?

          new_collection = Collection.new(new_lines)
          yield new_collection unless new_collection.empty?

          sleep 0.5
        end
      end

      def size
        ::File.size(path)
      end

      def exist?
        ::File.exist?(path)
      end

      def mtime
        ::File.mtime(path)
      end

      private

      attr_writer :path, :last_position

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
