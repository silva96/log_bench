# frozen_string_literal: true

module LogBench
  module Log
    class Collection
      include Enumerable

      attr_accessor :entries

      def initialize(input)
        self.parsed_entries = nil
        self.entries = parse_input(input)
      end

      def size
        entries.size
      end

      def empty?
        entries.empty?
      end

      def requests
        entries.select { |entry| entry.is_a?(Request) && !entry.orphan }
      end

      def orphan_requests
        entries.select { |entry| entry.is_a?(Request) && entry.orphan }
      end

      def filter_by_method(method)
        filtered_requests = requests.select { |req| req.method == method.upcase }
        create_collection_from_requests(filtered_requests)
      end

      def filter_by_path(path_pattern)
        filtered_requests = requests.select { |req| req.path.include?(path_pattern) }
        create_collection_from_requests(filtered_requests)
      end

      def filter_by_status(status_range)
        filtered_requests = requests.select { |req| status_range.include?(req.status) }
        create_collection_from_requests(filtered_requests)
      end

      def slow_requests(threshold_ms = 1000)
        filtered_requests = requests.select { |req| req.duration && req.duration > threshold_ms }
        create_collection_from_requests(filtered_requests)
      end

      def sort_by_duration
        sorted_requests = requests.sort_by { |req| -(req.duration || 0) }
        create_collection_from_requests(sorted_requests)
      end

      def sort_by_timestamp
        sorted_requests = requests.sort_by(&:timestamp)
        create_collection_from_requests(sorted_requests)
      end

      private

      attr_accessor :parsed_entries

      def create_collection_from_requests(requests)
        new_collection = self.class.new([])
        new_collection.entries = requests
        new_collection
      end

      def parse_input(input)
        lines = normalize_input(input)
        self.parsed_entries = Parser.parse_lines(lines)
        Parser.group_by_request(parsed_entries)
      end

      def normalize_input(input)
        case input
        when String
          [input]
        when Array
          input.flat_map { |item| normalize_input(item) }
        else
          Array(input)
        end
      end
    end
  end
end
