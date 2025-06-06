require "rails/railtie"

module LogBench
  class Railtie < Rails::Railtie
    railtie_name :log_bench

    # LogBench uses manual configuration (see README.md)

    # Provide helpful rake tasks
    rake_tasks do
      load "tasks/log_bench.rake"
    end

    # Show installation instructions when Rails starts in development
    initializer "log_bench.show_instructions", after: :load_config_initializers do
      if Rails.env.development?
        # Check if lograge is properly configured
        puts "\n" + "=" * 70
        puts "\n" + "=" * 70
        if Rails.application.config.respond_to?(:lograge) &&
            Rails.application.config.lograge.enabled
          puts "✅ LogBench is ready to use!"
          puts "=" * 70
          puts "View your logs: bundle exec log_bench log/development.log"
        else

          puts "🚀 LogBench is ready to configure!"
          puts "=" * 70
          puts "To start using LogBench:"
          puts "  1. See README.md for configuration instructions"
          puts "  2. Configure lograge in config/environments/development.rb"
          puts "  3. Restart your Rails server"
          puts "  4. Make some requests to generate logs"
          puts "  5. View logs: bundle exec log_bench log/development.log"
          puts
        end
        puts "For help: bundle exec log_bench --help"
        puts "=" * 70 + "\n"
        puts "=" * 70 + "\n"
      end
    end
  end
end
