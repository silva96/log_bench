# frozen_string_literal: true

module LogBench
  module Setup
    def setup
      return raise "already setup" if @_already_setup

      yield(configuration) if block_given?
      configure_rails_logging

      @_already_setup = true
    end

    def enabled?
      configuration.enabled?
    end

    private

    def configure_rails_logging
      return unless defined?(Rails)
      return unless enabled?

      Rails.application.configure do |app|
        app.config.lograge.enabled = true
        app.config.lograge.formatter = Lograge::Formatters::Json.new

        app.config.lograge.custom_options = lambda do |event|
          event.payload[:params]&.except("controller", "action")
            .presence&.then { |p| {params: p} }
        end

        app.config.logger ||= ActiveSupport::Logger.new(app.config.default_log_file)
        app.config.logger.formatter = LogBench::JsonFormatter.new
      end
    end
  end
end
