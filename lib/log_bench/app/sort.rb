module LogBench
  module App
    class Sort
      MODES = [:timestamp, :duration, :method, :status].freeze
      REQUEST_COLUMN_TO_MODE = {
        method: :method,
        status: :status,
        time: :duration
      }.freeze
      DEFAULT_DIRECTIONS = {
        timestamp: :asc,
        duration: :desc,
        method: :asc,
        status: :desc
      }.freeze
      ASC_ARROW = "↑"
      DESC_ARROW = "↓"

      def initialize
        self.mode = :timestamp
        self.direction = DEFAULT_DIRECTIONS.fetch(mode)
      end

      def cycle
        current_index = MODES.index(mode)
        next_index = (current_index + 1) % MODES.length
        self.mode = MODES[next_index]
        self.direction = DEFAULT_DIRECTIONS.fetch(mode)
      end

      def toggle_column(column)
        target_mode = REQUEST_COLUMN_TO_MODE[column]
        return false unless target_mode

        if mode == target_mode
          if direction == DEFAULT_DIRECTIONS.fetch(mode)
            toggle_direction
          else
            reset_to_default_sort
          end
        else
          self.mode = target_mode
          self.direction = DEFAULT_DIRECTIONS.fetch(mode)
        end

        true
      end

      def sort_arrow_for_column(column)
        target_mode = REQUEST_COLUMN_TO_MODE[column]
        return nil unless target_mode == mode

        (direction == :asc) ? ASC_ARROW : DESC_ARROW
      end

      def display_name
        mode_name = case mode
        when :timestamp then "TIMESTAMP"
        when :duration then "DURATION"
        when :method then "METHOD"
        when :status then "STATUS"
        end

        "#{mode_name} #{direction.to_s.upcase}"
      end

      def sort_requests(requests)
        sorted = case mode
        when :timestamp
          requests.sort_by { |req| req.timestamp || Time.at(0) }
        when :duration
          requests.sort_by { |req| req.duration || 0 }
        when :method
          requests.sort_by { |req| req.method || "" }
        when :status
          requests.sort_by { |req| req.status || 0 }
        else
          requests
        end

        (direction == :desc) ? sorted.reverse : sorted
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

      attr_accessor :mode, :direction

      def toggle_direction
        self.direction = (direction == :asc) ? :desc : :asc
      end

      def reset_to_default_sort
        self.mode = :timestamp
        self.direction = DEFAULT_DIRECTIONS.fetch(mode)
      end
    end
  end
end
