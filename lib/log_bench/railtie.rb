require 'rails/railtie'

module LogBench
  class Railtie < Rails::Railtie
    railtie_name :log_bench

    # Add LogBench generators to Rails
    generators do
      require 'generators/log_bench/install_generator'
    end

    # Provide helpful rake tasks
    rake_tasks do
      load 'tasks/log_bench.rake'
    end

    # Show installation instructions when Rails starts in development
    initializer "log_bench.show_instructions", after: :load_config_initializers do
      if Rails.env.development?
        # Check if lograge is properly configured
        unless Rails.application.config.respond_to?(:lograge) &&
               Rails.application.config.lograge.enabled

          puts "\n" + "="*70
          puts "🚀 LogBench is ready to configure!"
          puts "="*70
          puts "To start using LogBench:"
          puts "  1. Configure lograge: bundle exec rails generate log_bench:install"
          puts "  2. Restart your Rails server"
          puts "  3. Make some requests to generate logs"
          puts "  4. View logs: bundle exec log_bench log/development.log"
          puts
          puts "For help: bundle exec log_bench --help"
          puts "="*70 + "\n"
        else
          puts "\n" + "="*70
          puts "✅ LogBench is ready to use!"
          puts "="*70
          puts "View your logs: bundle exec log_bench log/development.log"
          puts "For help: bundle exec log_bench --help"
          puts "="*70 + "\n"
        end
      end
    end
  end
end
