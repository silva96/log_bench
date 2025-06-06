namespace :log_bench do
  desc "Show LogBench configuration instructions"
  task :install do
    puts "LogBench Configuration Instructions:"
    puts
    puts "Please see the README.md for complete setup instructions:"
    puts "https://github.com/silva96/log_bench#configuration"
    puts
    puts "Quick setup:"
    puts "1. Add 'require \"lograge\"' to config/environments/development.rb"
    puts "2. Configure lograge and JsonFormatter (see README)"
    puts "3. Set up Current model and ApplicationController"
    puts "4. Restart Rails server"
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
        puts "   See README.md for configuration instructions"
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
      puts "   Command: log_bench #{log_file}"
    else
      puts "❌ Lograge is not enabled"
      puts
      puts "To fix this:"
      puts "   1. See README.md for configuration instructions"
      puts "   2. Configure lograge in config/environments/development.rb"
      puts "   3. Restart your Rails server"
      puts "   4. Make some requests"
      puts "   5. Run: log_bench log/development.log"
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
           
        3. Configure lograge (see README.md):
           https://github.com/silva96/log_bench#configuration
           
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
