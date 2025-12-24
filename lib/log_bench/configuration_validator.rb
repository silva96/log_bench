# frozen_string_literal: true

module LogBench
  # Validates that the logger is properly configured for LogBench
  class ConfigurationValidator
    class ConfigurationError < StandardError; end

    LOGRAGE_ERROR_CONFIGS = {
      enabled: {
        title: "Lograge is not enabled",
        description: "LogBench requires lograge to be enabled in your Rails application."
      },
      options: {
        title: "Lograge custom_options missing",
        description: "LogBench needs custom_options to include params fields."
      },
      lograge_formatter: {
        title: "Wrong lograge formatter",
        description: "LogBench requires Lograge::Formatters::Json for lograge formatting."
      },
      logger_formatter: {
        title: "Wrong Rails logger formatter",
        description: "LogBench requires LogBench::JsonFormatter for Rails logger formatting."
      }
    }.freeze

    SEMANTIC_LOGGER_ERROR_CONFIGS = {
      not_defined: {
        title: "SemanticLogger is not defined",
        description: "LogBench requires semantic_logger gem to be installed when using logger_type: :semantic_logger."
      },
      not_configured: {
        title: "SemanticLogger is not configured",
        description: "LogBench requires SemanticLogger to be configured as the Rails logger."
      }
    }.freeze

    def self.validate_rails_config!
      new.validate_rails_config!
    end

    def validate_rails_config!
      return true unless defined?(Rails) && Rails.application
      return true unless LogBench.configuration.enabled

      case LogBench.configuration.logger_type
      when :lograge
        validate_lograge_config!
      when :semantic_logger
        validate_semantic_logger_config!
      end

      true
    end

    private

    def validate_lograge_config!
      validate_lograge_enabled!
      validate_custom_options!
      validate_lograge_formatter!
      validate_logger_formatter!
    end

    def validate_semantic_logger_config!
      validate_semantic_logger_defined!
      validate_semantic_logger_configured!
    end

    def validate_lograge_enabled!
      unless lograge_config&.enabled
        raise ConfigurationError, build_error_message(:enabled, :lograge)
      end
    end

    def validate_custom_options!
      unless lograge_config&.custom_options
        raise ConfigurationError, build_error_message(:options, :lograge)
      end
    end

    def validate_lograge_formatter!
      formatter = lograge_config&.formatter
      unless formatter.is_a?(Lograge::Formatters::Json)
        raise ConfigurationError, build_error_message(:lograge_formatter, :lograge)
      end
    end

    def validate_logger_formatter!
      logger = Rails.logger
      formatter = logger&.formatter
      unless formatter.is_a?(LogBench::JsonFormatter)
        raise ConfigurationError, build_error_message(:logger_formatter, :lograge)
      end
    end

    def validate_semantic_logger_defined!
      unless defined?(SemanticLogger)
        raise ConfigurationError, build_error_message(:not_defined, :semantic_logger)
      end
    end

    def validate_semantic_logger_configured!
      # Check if Rails.logger is a SemanticLogger, or if it wraps one (Rails 7.1+ BroadcastLogger)
      logger = Rails.logger
      is_semantic = logger.is_a?(SemanticLogger::Logger) ||
        (logger.respond_to?(:broadcasts) && logger.broadcasts.any? { |l| l.is_a?(SemanticLogger::Logger) })

      unless is_semantic
        raise ConfigurationError, build_error_message(:not_configured, :semantic_logger)
      end
    end

    def lograge_config
      return nil unless Rails.application.config.respond_to?(:lograge)
      Rails.application.config.lograge
    end

    def error_configs_for(logger_type)
      case logger_type
      when :lograge
        LOGRAGE_ERROR_CONFIGS
      when :semantic_logger
        SEMANTIC_LOGGER_ERROR_CONFIGS
      end
    end

    def build_error_message(error_type, logger_type)
      config = error_configs_for(logger_type)[error_type]

      <<~ERROR
        ❌ #{config[:title]}

        #{config[:description]}

        This should be automatically configured by LogBench, but something went wrong.

        For complete setup: https://github.com/silva96/log_bench#configuration
      ERROR
    end
  end
end
