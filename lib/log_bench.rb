# frozen_string_literal: true

require "zeitwerk"
require "json"
require "time"
require "curses"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module LogBench
  class Error < StandardError; end

  extend LogBench::Parse

  class << self
    attr_accessor :configuration

    def setup
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end
end

# Load Railtie if Rails is available
require "log_bench/railtie" if defined?(Rails)
