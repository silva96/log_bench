namespace :log_bench do
  desc "Install and configure LogBench with lograge"
  task :install do
    puts "Installing LogBench configuration..."

    if defined?(Rails)
      # Run the Rails generator
      system("rails generate log_bench:install")
    else
      puts "This task should be run from a Rails application directory."
      puts "Alternatively, run: rails generate log_bench:install"
    end
  end

  desc "Check LogBench configuration"
  task check: :environment do
    puts "\n" + "=" * 60
    puts "🔍 LogBench Configuration Check"
    puts "=" * 60

    if Rails.application.config.respond_to?(:lograge) &&
        Rails.application.config.lograge.enabled
      puts "✅ Lograge is enabled"

      if Rails.application.config.lograge.formatter.is_a?(Lograge::Formatters::Json)
        puts "✅ JSON formatter is configured"
      else
        puts "⚠️  JSON formatter is not configured"
        puts "   LogBench requires JSON format"
        puts "   Run: rails generate log_bench:install"
      end

      # Check if log file exists and has content
      log_file = "log/#{Rails.env}.log"
      if File.exist?(log_file) && File.size(log_file) > 0
        puts "✅ Log file exists: #{log_file}"
      else
        puts "⚠️  Log file is empty or doesn't exist: #{log_file}"
        puts "   Make some requests to generate logs"
      end

      puts
      puts "🎉 LogBench is ready to use!"
      puts "   Command: bundle exec log_bench #{log_file}"
    else
      puts "❌ Lograge is not enabled"
      puts
      puts "To fix this:"
      puts "   1. Run: bundle exec rails generate log_bench:install"
      puts "   2. Restart your Rails server"
      puts "   3. Make some requests"
      puts "   4. Run: bundle exec log_bench log/development.log"
    end
    puts "=" * 60 + "\n"
  end

  desc "Show LogBench usage instructions"
  task :help do
    puts <<~HELP
      LogBench - Rails Log Viewer
      
      Installation:
        1. Add to your Gemfile (development group):
           gem 'log_bench', group: :development
           
        2. Run bundle install:
           bundle install
           
        3. Configure lograge:
           rails generate log_bench:install
           
        4. Restart your Rails server
      
      Usage:
        # View current development log
        log_bench
        
        # View specific log file
        log_bench log/development.log
        log_bench log/production.log
        
        # View log file from another directory
        log_bench /path/to/your/app/log/development.log
      
      Features:
        - Real-time log monitoring
        - Interactive TUI with dual panes
        - Request filtering and sorting
        - SQL query analysis
        - Color-coded HTTP methods and status codes
        
      Requirements:
        - Lograge gem with JSON formatter
        - Rails application logs in lograge format
    HELP
  end
end
