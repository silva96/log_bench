# frozen_string_literal: true

module LogBench
  class Configuration
    VALID_LOGGER_TYPES = %i[lograge logstruct].freeze

    attr_accessor :show_init_message, :enabled, :base_controller_classes, :configure_logger_automatically
    attr_reader :logger_type

    def initialize
      @show_init_message = :full
      @enabled = (defined?(Rails) && Rails.respond_to?(:env)) ? Rails.env.development? : false
      @base_controller_classes = %w[ApplicationController ActionController::Base]
      @configure_logger_automatically = true  # Configure logger by default
      @logger_type = :lograge  # Default to lograge for backward compatibility
    end

    # Backward compatibility alias
    alias_method :configure_lograge_automatically, :configure_logger_automatically
    alias_method :configure_lograge_automatically=, :configure_logger_automatically=

    def logger_type=(value)
      value = value.to_sym if value.is_a?(String)
      unless VALID_LOGGER_TYPES.include?(value)
        raise ArgumentError, "Invalid logger_type: #{value}. Valid options: #{VALID_LOGGER_TYPES.join(", ")}"
      end
      @logger_type = value
    end

    def logstruct?
      @logger_type == :logstruct
    end

    def lograge?
      @logger_type == :lograge
    end
  end
end
