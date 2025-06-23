# frozen_string_literal: true

module LogBench
  module Parse
    def parse(lines)
      lines = [lines] if lines.is_a?(String)
      collection = Log::Collection.new(lines)
      collection.requests
    end
  end
end
