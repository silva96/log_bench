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

  class << self
    attr_accessor :configuration

    def setup
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def logger
      @logger ||= create_debug_logger
    end

    private

    def create_debug_logger
      require "logger"
      logger = Logger.new("logbench_log.log")
      logger.level = Logger::DEBUG
      logger.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{severity}: #{msg}\n"
      end
      logger
    end
  end
end

# Load Railtie if Rails is available
require "log_bench/railtie" if defined?(Rails)
