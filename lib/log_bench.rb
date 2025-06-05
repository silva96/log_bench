# frozen_string_literal: true

require "zeitwerk"
require "json"
require "time"
require "curses"
require_relative "log_bench/version"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module LogBench
  class Error < StandardError; end

  # Parse log lines and return an array of entries
  def self.parse(lines)
    lines = [lines] if lines.is_a?(String)

    collection = Log::Collection.new(lines)
    collection.requests
  end
end

# Load Railtie if Rails is available
require "log_bench/railtie" if defined?(Rails)
