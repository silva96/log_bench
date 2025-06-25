# frozen_string_literal: true

module LogBench
  module Parse
    def parse(lines)
      lines = Array(lines)
      collection = Log::Collection.new(lines)
      collection.requests
    end
  end
end
