# frozen_string_literal: true

module LogBench
  module Setup
    def setup
      yield(configuration)
    end
  end
end
