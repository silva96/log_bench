require "rails/railtie"

module LogBench
  class Railtie < Rails::Railtie
    LINE = "=" * 70

    railtie_name :log_bench

    config.log_bench = ActiveSupport::OrderedOptions.new

    # LogBench uses manual configuration (see README.md)

    # Provide helpful rake tasks
    rake_tasks do
      load "tasks/log_bench.rake"
    end

    initializer "log_bench.configure" do |app|
      LogBench.setup do |config|
        config.show_init_message = app.config.log_bench.show_init_message
        config.show_init_message = :full if config.show_init_message.nil?
      end
    end

    # Show installation instructions when Rails starts in development
    initializer "log_bench.show_instructions", after: :load_config_initializers do
      return unless Rails.env.development?

      # Check if lograge is properly configured
      if Rails.application.config.respond_to?(:lograge) && Rails.application.config.lograge.enabled
        if LogBench.configuration.show_init_message.eql? :full
          print_full_init_message
          print_help_instructions
          puts LINE
          puts LINE
        elsif LogBench.configuration.show_init_message.eql? :min
          print_min_init_message
        end
      else
        print_configuration_instructions
        print_help_instructions
        puts LINE
        puts LINE
      end
    end

    private

    def print_configuration_instructions
      puts "🚀 LogBench is ready to configure!"
      puts LINE
      puts "To start using LogBench:"
      puts "  1. See README.md for configuration instructions"
      puts "  2. Configure lograge in config/environments/development.rb"
      puts "  3. Restart your Rails server"
      puts "  4. Make some requests to generate logs"
      puts "  5. View logs: log_bench log/development.log"
      puts ""
    end

    def print_min_init_message
      puts "✅ LogBench is ready to use!"
    end

    def print_full_init_message
      puts "\n" + LINE
      puts "\n" + LINE
      puts "✅ LogBench is ready to use!"
      puts LINE
      puts "View your logs: log_bench log/development.log"
    end

    def print_help_instructions
      puts "For help: log_bench --help"
    end
  end
end
