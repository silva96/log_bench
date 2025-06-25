require "rails/railtie"

module LogBench
  class Railtie < Rails::Railtie
    LINE = "=" * 70
    HELP_INSTRUCTIONS = "For help: log_bench --help"
    MIN_INIT_MESSAGE = "✅ LogBench is ready to use!"
    FULL_INIT_MESSAGE = <<~MSG.chomp
      \n#{LINE}
      \n#{LINE}
      #{MIN_INIT_MESSAGE}
      #{LINE}
      View your logs: log_bench log/development.log
    MSG
    CONFIGURATION_INSTRUCTIONS = <<~INSTRUCTIONS
      \n#{LINE}
      \n#{LINE}
      🚀 LogBench is ready to configure!
      #{LINE}
      To start using LogBench:
    INSTRUCTIONS

    railtie_name :log_bench

    config.log_bench = ActiveSupport::OrderedOptions.new

    # Provide helpful rake tasks
    rake_tasks do
      load "tasks/log_bench.rake"
    end

    initializer "log_bench.configure" do |app|
      # Not necessary any more.
    end

    # Show installation instructions when Rails starts in development
    initializer "log_bench.show_instructions", after: :load_config_initializers do
      return unless Rails.env.development?
      return unless LogBench.enabled?

      validate_lograge_config
    end

    private

    # Use configuration validator to check lograge setup
    def validate_lograge_config
      ConfigurationValidator.validate_rails_config!
      print_configured_init_message
    rescue ConfigurationValidator::ConfigurationError => e
      print_configuration_error_message(e)
    end

    # Lograge is properly configured
    def print_configured_init_message
      case LogBench.configuration.show_init_message
      when :full, nil
        puts FULL_INIT_MESSAGE, HELP_INSTRUCTIONS, LINE, LINE
      when :min
        puts MIN_INIT_MESSAGE
      end
    end

    # Lograge needs configuration
    def print_configuration_error_message(error)
      puts CONFIGURATION_INSTRUCTIONS
      puts "⚠️  Configuration issue: #{error.message}"
      puts HELP_INSTRUCTIONS, LINE, LINE
    end
  end
end
