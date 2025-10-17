require "rails/railtie"
require "lograge"

module LogBench
  class Railtie < Rails::Railtie
    LINE = "=" * 70
    HELP_INSTRUCTIONS = "For help: log_bench --help"
    MIN_INIT_MESSAGE = "✅ LogBench is ready to use!"
    FULL_INIT_MESSAGE = <<~MSG.chomp
      #{MIN_INIT_MESSAGE}
      View your logs: log_bench log/development.log
    MSG

    railtie_name :log_bench

    config.log_bench = ActiveSupport::OrderedOptions.new

    # Provide helpful rake tasks
    rake_tasks do
      load "tasks/log_bench.rake"
    end

    # Run AFTER user initializers to pick up their configuration
    initializer "log_bench.configure", after: :load_config_initializers do |app|
      LogBench.setup
    end

    # Show success message when Rails starts in development
    initializer "log_bench.show_instructions", after: "log_bench.configure" do
      next unless Rails.env.development? && LogBench.configuration.enabled

      print_configured_init_message
    rescue => e
      puts LINE
      puts "⚠️  LogBench setup issue: #{e.message} at: \n#{e.backtrace.join("\n")}"
      puts HELP_INSTRUCTIONS
      puts LINE
    end

    # Configure lograge after the gem was already configured
    initializer "log_bench.configure_lograge", after: "log_bench.configure" do |app|
      if LogBench.configuration.enabled
        LogBench::Railtie.setup_lograge(app)
      end
    end

    config.after_initialize do
      if LogBench.configuration.enabled
        LogBench::Railtie.setup_rails_logger_final
        LogBench::Railtie.setup_current_attributes
        LogBench::Railtie.setup_sidekiq_middleware
        LogBench::Railtie.validate_configuration!
      end
    end

    class << self
      def setup_lograge(app)
        return unless LogBench.configuration.configure_lograge_automatically

        app.config.lograge.enabled = true
        app.config.lograge.formatter = Lograge::Formatters::Json.new
        app.config.lograge.custom_options = lambda do |event|
          params = event.payload[:params]&.except("controller", "action")
          {params: params} if params.present?
        end
      end

      def setup_current_attributes
        # Inject Current.request_id into base controllers
        LogBench.configuration.base_controller_classes.each do |controller_class_name|
          controller_class = controller_class_name.safe_constantize
          next unless controller_class

          inject_current_request_id(controller_class)
        end
      end

      def setup_rails_logger_final
        # Get the underlying logger (unwrap TaggedLogging if present)
        base_logger = Rails.logger.respond_to?(:logger) ? Rails.logger.logger : Rails.logger
        base_logger.formatter = LogBench::JsonFormatter.new
        # Re-wrap with TaggedLogging to maintain Rails compatibility
        Rails.logger = ActiveSupport::TaggedLogging.new(base_logger)
      end

      def inject_current_request_id(controller_class)
        return if controller_class.method_defined?(:set_current_request_id)

        controller_class.class_eval do
          before_action :set_current_request_id

          private

          def set_current_request_id
            LogBench::Current.request_id = request.request_id if defined?(LogBench::Current)
          end
        end
      end

      def setup_sidekiq_middleware
        return unless defined?(Sidekiq)

        require "sidekiq/middleware/current_attributes"
        Sidekiq::CurrentAttributes.persist("LogBench::Current")

        # Add our custom middleware to capture job ID
        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add LogBench::SidekiqMiddleware
          end
        end
      end

      # Validate that LogBench setup worked correctly
      def validate_configuration!
        ConfigurationValidator.validate_rails_config!
      rescue ConfigurationValidator::ConfigurationError => e
        puts LINE
        puts "❌ LogBench Configuration Error:"
        puts e.message
        puts "LogBench will be disabled until this is fixed."
        puts LINE
      end
    end

    private

    def print_configured_init_message
      case LogBench.configuration.show_init_message
      when :full, nil
        puts LINE, FULL_INIT_MESSAGE, HELP_INSTRUCTIONS, LINE
      when :min
        puts MIN_INIT_MESSAGE
      end
    end
  end
end
