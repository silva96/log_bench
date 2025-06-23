# frozen_string_literal: true

module LogBench
  module Setup
    def setup
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end
end
