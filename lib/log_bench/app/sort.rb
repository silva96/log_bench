module LogBench
  module App
    class Sort
      MODES = [:timestamp, :duration, :method, :status].freeze

      def initialize
        self.mode = :timestamp
      end

      def cycle
        current_index = MODES.index(mode)
        next_index = (current_index + 1) % MODES.length
        self.mode = MODES[next_index]
      end

      def display_name
        case mode
        when :timestamp then "TIMESTAMP"
        when :duration then "DURATION"
        when :method then "METHOD"
        when :status then "STATUS"
        end
      end

      def sort_requests(requests)
        case mode
        when :timestamp
          requests.sort_by { |req| req.timestamp || Time.at(0) }
        when :duration
          requests.sort_by { |req| -(req.duration || 0) }  # Descending (slowest first)
        when :method
          requests.sort_by { |req| req.method || "" }
        when :status
          requests.sort_by { |req| -(req.status || 0) }  # Descending (errors first)
        else
          requests
        end
      end

      def timestamp?
        mode == :timestamp
      end

      def duration?
        mode == :duration
      end

      def method?
        mode == :method
      end

      def status?
        mode == :status
      end

      private

      attr_accessor :mode
    end
  end
end
