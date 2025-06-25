namespace :log_bench do
  desc "Show LogBench configuration instructions"
  task :install do
    puts "LogBench Configuration Instructions:"
    puts
    puts "LogBench is automatically enabled in development!"
    puts "Just restart your Rails server and it will work."
    puts
    puts "For customization or other environments, see:"
    puts "https://github.com/silva96/log_bench#configuration"
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
           
        3. Optionally configure log_bench (see README.md):
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
        - Color-coded HTTP methods and status codess
    HELP
  end
end
