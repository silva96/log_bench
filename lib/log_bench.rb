# frozen_string_literal: true

require "zeitwerk"
require "json"
require "time"
require "curses"
require "lograge"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module LogBench
  class Error < StandardError; end

  class Configuration
    attr_accessor :show_init_message
  end

  class << self
    attr_accessor :configuration

    # Parse log lines and return an array of entries
    def parse(lines)
      lines = [lines] if lines.is_a?(String)

      collection = Log::Collection.new(lines)
      collection.requests
    end

    def setup
      self.configuration ||= Configuration.new
      return if @already_setup

      yield(configuration) if block_given?
      configure_rails_logging if defined?(Rails)

      @already_setup = true
    end

    private

    def configure_rails_logging
      Rails.application.configure do
        config.lograge.enabled = true
        config.lograge.formatter = Lograge::Formatters::Json.new

        config.lograge.custom_options = lambda do |event|
          event.payload[:params]&.except("controller", "action")
            .presence&.then { |p| {params: p} }
        end

        config.logger ||= ActiveSupport::Logger.new(config.default_log_file)
        config.logger.formatter = LogBench::JsonFormatter.new
      end
    end
  end
end

# Load Railtie if Rails is available
require "log_bench/railtie" if defined?(Rails)
