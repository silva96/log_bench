# frozen_string_literal: true

module LogBench
  module Setup
    def setup
      return if @_already_setup

      yield(configuration) if block_given?
      configure_rails_logging

      @_already_setup = true
    end

    def configure_rails_logging
      return unless defined?(Rails)

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
