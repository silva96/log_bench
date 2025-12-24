# frozen_string_literal: true

require "test_helper"

class TestLogBench < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::LogBench::VERSION
  end

  def test_parse_lograge_json
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_instance_of LogBench::Log::Request, request
    assert_equal "GET", request.method
    assert_equal "/users", request.path
    assert_equal 200, request.status
    assert_equal 45.2, request.duration
  end

  def test_parse_sql_query
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_sql)
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_equal 1, request.queries.size

    query = request.queries.first
    assert_instance_of LogBench::Log::QueryEntry, query
    assert query.select?
    assert_equal 1.2, query.duration_ms
  end

  def test_parse_cache_entry
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_cache)
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_equal 1, request.cache_operations.size

    cache_op = request.cache_operations.first
    assert_instance_of LogBench::Log::QueryEntry, cache_op
    assert cache_op.cached?
    assert cache_op.hit?
    assert_equal 0.1, cache_op.duration_ms
  end

  def test_collection_filtering
    collection = LogBench::Log::Collection.new(TestFixtures.simple_log_lines)
    requests = collection.requests

    assert_equal 2, requests.size

    get_requests = collection.filter_by_method("GET")
    assert_equal 1, get_requests.requests.size
    assert_equal "GET", get_requests.requests.first.method

    slow_requests = collection.slow_requests(100)
    assert_equal 1, slow_requests.requests.size
    assert_equal "POST", slow_requests.requests.first.method
  end

  def test_parse_log_file
    log_file = LogBench::Log::File.new(TestFixtures.simple_log_path)
    requests = log_file.requests

    assert_equal 2, requests.size
    assert_equal "GET", requests.first.method
    assert_equal "POST", requests.last.method
  end

  def test_parse_request_with_hash_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_hash_params])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_instance_of LogBench::Log::Request, request

    # Check that params are parsed correctly
    refute_nil request.params
    assert_instance_of Hash, request.params
    assert_equal "1", request.params["id"]
    assert_equal "John Doe", request.params["user"]["name"]
    assert_equal "john@example.com", request.params["user"]["email"]
  end

  def test_parse_request_with_string_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_string_params])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # Check that JSON string params are parsed correctly
    refute_nil request.params
    assert_instance_of Hash, request.params
    assert_equal "5", request.params["id"]
    assert_equal "Updated Title", request.params["post"]["title"]
  end

  def test_parse_request_with_simple_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_simple_params])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # Check that simple params are parsed correctly
    refute_nil request.params
    assert_instance_of Hash, request.params
    assert_equal "1", request.params["user_id"]
  end

  def test_parse_request_without_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # Check that missing params are handled correctly
    assert_nil request.params
  end

  def test_parse_request_with_invalid_json_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_invalid_json_params])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # Check that invalid JSON params are handled as strings
    refute_nil request.params
    assert_instance_of String, request.params
    assert_equal "{invalid json", request.params
  end

  def test_configuration_validator_validates_rails_config
    # Since we're not in a Rails environment during tests,
    # the validator should return true (no Rails app to validate)
    # We'll just test that the method exists and can be called
    validator = LogBench::ConfigurationValidator.new
    assert_respond_to validator, :validate_rails_config!
  end

  def test_configuration_validator_returns_true_when_disabled
    # When LogBench is disabled, validation should pass without checking logger config
    LogBench.setup { |config| config.enabled = false }

    validator = LogBench::ConfigurationValidator.new
    assert validator.validate_rails_config!
  ensure
    LogBench.setup { |config| config.enabled = true }
  end

  def test_configuration_validator_error_configs_are_frozen
    # Error configs should be immutable
    assert LogBench::ConfigurationValidator::LOGRAGE_ERROR_CONFIGS.frozen?
    assert LogBench::ConfigurationValidator::SEMANTIC_LOGGER_ERROR_CONFIGS.frozen?
  end

  def test_configuration_validator_lograge_errors_have_required_fields
    LogBench::ConfigurationValidator::LOGRAGE_ERROR_CONFIGS.each do |key, config|
      assert config[:title], "Lograge error #{key} should have a title"
      assert config[:description], "Lograge error #{key} should have a description"
    end
  end

  def test_configuration_validator_semantic_logger_errors_have_required_fields
    LogBench::ConfigurationValidator::SEMANTIC_LOGGER_ERROR_CONFIGS.each do |key, config|
      assert config[:title], "SemanticLogger error #{key} should have a title"
      assert config[:description], "SemanticLogger error #{key} should have a description"
    end
  end

  def test_json_formatter_implements_rails_logger_interface
    formatter = LogBench::JsonFormatter.new

    # Test that it responds to the Rails Logger::Formatter interface
    assert_respond_to formatter, :call

    # Test with Rails logger arguments (severity, timestamp, progname, message)
    severity = "INFO"
    timestamp = Time.now
    progname = "Rails"
    message = "Test message"

    result = formatter.call(severity, timestamp, progname, message)

    # Should return a JSON string with newline
    assert result.is_a?(String)
    assert result.end_with?("\n")

    # Should be valid JSON
    parsed = JSON.parse(result.chomp)
    assert parsed.is_a?(Hash)
    assert_equal severity, parsed["level"]
    assert_equal progname, parsed["progname"]
  end

  def test_json_formatter_handles_lograge_messages
    formatter = LogBench::JsonFormatter.new

    # Test with a lograge-style JSON message
    lograge_message = '{"method":"GET","path":"/users","status":200,"duration":45.2}'

    result = formatter.call("INFO", Time.now, "Rails", lograge_message)
    parsed = JSON.parse(result.chomp)

    # Should parse and include lograge fields
    assert_equal "GET", parsed["method"]
    assert_equal "/users", parsed["path"]
    assert_equal 200, parsed["status"]
    assert_equal 45.2, parsed["duration"]
  end

  def test_json_formatter_handles_tagged_logging
    formatter = LogBench::JsonFormatter.new

    # Test with TaggedLogging format: [tag1] [tag2] message
    # Note: When calling formatter directly (without TaggedLogging wrapper),
    # tags won't be extracted since TaggedLogging manages the tag stack
    tagged_message = "[API] [User123] Processing user request"

    result = formatter.call("INFO", Time.now, "Rails", tagged_message)
    parsed = JSON.parse(result.chomp)

    # Without TaggedLogging wrapper, message is treated as plain text
    assert_nil parsed["tags"]  # No tags when called directly
    assert_equal "[API] [User123] Processing user request", parsed["message"]
    assert_equal "INFO", parsed["level"]
  end

  def test_json_formatter_handles_mixed_tagged_and_lograge
    formatter = LogBench::JsonFormatter.new

    # Test with tags + lograge JSON
    # Note: Without TaggedLogging wrapper, this is treated as a lograge message
    tagged_lograge = '[ActiveJob] {"method":"POST","path":"/jobs","status":200}'

    result = formatter.call("INFO", Time.now, "Rails", tagged_lograge)
    parsed = JSON.parse(result.chomp)

    # Without TaggedLogging wrapper, the [ActiveJob] part is treated as message text
    assert_nil parsed["tags"]  # No tags when called directly
    assert_equal '[ActiveJob] {"method":"POST","path":"/jobs","status":200}', parsed["message"]
  end

  def test_json_formatter_handles_no_tags
    formatter = LogBench::JsonFormatter.new

    # Test with regular message (no tags)
    regular_message = "Simple log message"

    result = formatter.call("INFO", Time.now, "Rails", regular_message)
    parsed = JSON.parse(result.chomp)

    # Should not have tags field
    assert_nil parsed["tags"]
    assert_equal "Simple log message", parsed["message"]
    assert_equal "INFO", parsed["level"]
  end

  def test_json_formatter_adds_colored_prefix_for_direct_sidekiq_job
    formatter = LogBench::JsonFormatter.new

    # Mock LogBench::Current to return both job ID and job class (direct Sidekiq job)
    LogBench::Current.jid = "test-job-id-123"
    LogBench::Current.job_class = "TestJob"

    result = formatter.call("INFO", Time.now, "Rails", "Job message")
    parsed = JSON.parse(result.chomp)

    # Should NOT include separate jid/job_class fields (we rely on message prefix now)
    refute parsed.key?("jid")
    refute parsed.key?("job_class")

    # Message should have colored job prefix (color based on job ID)
    message = parsed["message"]
    assert_match(/\A\u001b\[1m\u001b\[\d+m\[TestJob#test-job-id-123\]\u001b\[0m Job message\z/, message)

    # Verify the same job ID always gets the same color
    result2 = formatter.call("INFO", Time.now, "Rails", "Another message")
    parsed2 = JSON.parse(result2.chomp)
    message2 = parsed2["message"]

    # Extract color codes from both messages
    color1 = message.match(/\u001b\[1m\u001b\[(\d+)m/)[1] if /\u001b\[1m\u001b\[(\d+)m/.match?(message)
    color2 = message2.match(/\u001b\[1m\u001b\[(\d+)m/)[1] if /\u001b\[1m\u001b\[(\d+)m/.match?(message2)
    assert_equal color1, color2, "Same job ID should always get the same color"
    assert_equal "INFO", parsed["level"]
  ensure
    # Clean up
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil
  end

  def test_json_formatter_no_prefix_when_no_job_context
    formatter = LogBench::JsonFormatter.new

    # Ensure no job context is set
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil

    result = formatter.call("INFO", Time.now, "Rails", "Regular message")
    parsed = JSON.parse(result.chomp)

    # Should not include jid/job_class fields and no colored prefix
    refute parsed.key?("jid")
    refute parsed.key?("job_class")
    assert_equal "Regular message", parsed["message"]  # No prefix
    assert_equal "INFO", parsed["level"]
  end

  def test_json_formatter_adds_colored_job_prefix_from_current_attributes
    formatter = LogBench::JsonFormatter.new

    # Set job context (direct Sidekiq job)
    LogBench::Current.jid = "test-job-456"
    LogBench::Current.job_class = "MyTestJob"

    result = formatter.call("INFO", Time.now, "Rails", "Processing user data")
    parsed = JSON.parse(result.chomp)

    # Should NOT include separate jid/job_class fields (we rely on message prefix now)
    refute parsed.key?("jid")
    refute parsed.key?("job_class")

    # Message should have colored job prefix (color based on job ID)
    message = parsed["message"]
    assert_match(/\A\u001b\[1m\u001b\[\d+m\[MyTestJob#test-job-456\]\u001b\[0m Processing user data\z/, message)
    assert_equal "INFO", parsed["level"]
  ensure
    # Clean up
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil
  end

  def test_json_formatter_adds_colored_job_prefix_from_tags
    formatter = LogBench::JsonFormatter.new

    # No Current attributes set (ActiveJob scenario)
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil

    # Mock current_tags to return ActiveJob tags
    def formatter.current_tags
      ["ActiveJob", "EmailDeliveryJob", "email-job-789"]
    end

    result = formatter.call("INFO", Time.now, "Rails", "Sending email")
    parsed = JSON.parse(result.chomp)

    # Should NOT include separate jid/job_class fields (we rely on message prefix now)
    refute parsed.key?("jid")
    refute parsed.key?("job_class")

    # Message should have colored job prefix (color based on job ID)
    message = parsed["message"]
    assert_match(/\A\u001b\[1m\u001b\[\d+m\[EmailDeliveryJob#email-job-789\]\u001b\[0m Sending email\z/, message)
    assert_equal "INFO", parsed["level"]

    # Should include the original tags
    assert_equal ["ActiveJob", "EmailDeliveryJob", "email-job-789"], parsed["tags"]
  end

  def test_json_formatter_no_prefix_when_incomplete_job_context
    formatter = LogBench::JsonFormatter.new

    # Set only jid, no job class (incomplete context)
    LogBench::Current.jid = "test-job-789"
    LogBench::Current.job_class = nil

    result = formatter.call("INFO", Time.now, "Rails", "Some message")
    parsed = JSON.parse(result.chomp)

    # Should NOT include jid/job_class fields and no prefix (since context is incomplete)
    refute parsed.key?("jid")
    refute parsed.key?("job_class")
    assert_equal "Some message", parsed["message"]  # No prefix
    assert_equal "INFO", parsed["level"]
  ensure
    # Clean up
    LogBench::Current.jid = nil
  end

  def test_json_formatter_no_job_fields_when_no_context
    formatter = LogBench::JsonFormatter.new

    # No job context set
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil

    result = formatter.call("INFO", Time.now, "Rails", "Regular message")
    parsed = JSON.parse(result.chomp)

    # Should not include jid or job_class fields and no prefix
    refute parsed.key?("jid")
    refute parsed.key?("job_class")
    assert_equal "Regular message", parsed["message"]  # No prefix
    assert_equal "INFO", parsed["level"]
  end

  def test_sidekiq_middleware_sets_and_cleans_jid_and_job_class
    middleware = LogBench::SidekiqMiddleware.new
    worker = Object.new
    job = {"jid" => "test-sidekiq-job-123", "class" => "TestJob"}
    queue = "default"

    # Ensure attributes start as nil
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil
    assert_nil LogBench::Current.jid
    assert_nil LogBench::Current.job_class

    # Test that middleware sets attributes during execution
    jid_during_execution = nil
    job_class_during_execution = nil
    middleware.call(worker, job, queue) do
      jid_during_execution = LogBench::Current.jid
      job_class_during_execution = LogBench::Current.job_class
    end

    # Should have set attributes during execution
    assert_equal "test-sidekiq-job-123", jid_during_execution
    assert_equal "TestJob", job_class_during_execution

    # Should clean up attributes after execution
    assert_nil LogBench::Current.jid
    assert_nil LogBench::Current.job_class
  end

  def test_sidekiq_middleware_skips_activejob_wrapper
    middleware = LogBench::SidekiqMiddleware.new
    worker = Object.new

    # Simulate ActiveJob wrapper payload
    job = {
      "jid" => "activejob-wrapper-456",
      "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
      "args" => [
        {
          "job_class" => "EmailDeliveryJob",
          "job_id" => "some-uuid",
          "arguments" => ["user@example.com"]
        }
      ]
    }
    queue = "default"

    # Ensure attributes start as nil
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil

    # Test that middleware skips setting Current attributes for ActiveJob wrapper
    jid_during_execution = nil
    job_class_during_execution = nil
    middleware.call(worker, job, queue) do
      jid_during_execution = LogBench::Current.jid
      job_class_during_execution = LogBench::Current.job_class
    end

    # Should NOT set Current attributes for ActiveJob wrapper (relies on tags instead)
    assert_nil jid_during_execution
    assert_nil job_class_during_execution

    # Should clean up attributes after execution (should still be nil)
    assert_nil LogBench::Current.jid
    assert_nil LogBench::Current.job_class
  end

  def test_sidekiq_middleware_fallback_to_worker_class
    middleware = LogBench::SidekiqMiddleware.new

    # Create a mock worker with a specific class name
    worker_class = Class.new do
      def self.name
        "CustomWorkerClass"
      end
    end
    worker = worker_class.new

    # Job without class information
    job = {"jid" => "fallback-test-789"}
    queue = "default"

    # Ensure attributes start as nil
    LogBench::Current.jid = nil
    LogBench::Current.job_class = nil

    # Test that middleware falls back to worker class name
    jid_during_execution = nil
    job_class_during_execution = nil
    middleware.call(worker, job, queue) do
      jid_during_execution = LogBench::Current.jid
      job_class_during_execution = LogBench::Current.job_class
    end

    # Should have used worker class as fallback
    assert_equal "fallback-test-789", jid_during_execution
    assert_equal "CustomWorkerClass", job_class_during_execution

    # Should clean up attributes after execution
    assert_nil LogBench::Current.jid
    assert_nil LogBench::Current.job_class
  end

  def test_parse_entries_with_null_or_missing_message
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_null_message_logs)
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    assert_equal 2, request.related_logs.size

    request.related_logs.each do |log|
      assert_equal "", log.content
      refute_nil log.content
    end

    assert_equal :other, request.related_logs[0].type
    assert_equal :other, request.related_logs[1].type
  end

  def test_normalize_message_handles_string
    assert_equal "test message", LogBench::Log::Parser.normalize_message("test message")
  end

  def test_normalize_message_handles_array
    assert_equal "test message", LogBench::Log::Parser.normalize_message(["test", "message"])
  end

  def test_normalize_message_handles_nil
    assert_equal "", LogBench::Log::Parser.normalize_message(nil)
  end

  def test_normalize_message_handles_other_types
    assert_equal "123", LogBench::Log::Parser.normalize_message(123)
    assert_equal "true", LogBench::Log::Parser.normalize_message(true)
  end

  def test_sql_message_detection_with_array
    # Should detect SQL messages when message is an Array
    data1 = {"message" => ["SELECT", "*", "FROM", "users"]}
    assert LogBench::Log::Parser.sql_message?(data1), "Should detect SQL when message is an Array"

    data2 = {"message" => ["INSERT", "INTO", "posts"]}
    assert LogBench::Log::Parser.sql_message?(data2), "Should detect INSERT when message is an Array"

    data3 = {"message" => ["Regular", "log", "message"]}
    refute LogBench::Log::Parser.sql_message?(data3), "Should not detect SQL for regular Array message"
  end

  def test_cache_message_detection_with_array
    # Should detect cache messages when message is an Array
    data1 = {"message" => ["CACHE", "hit", "for", "key"]}
    assert LogBench::Log::Parser.cache_message?(data1), "Should detect CACHE when message is an Array"

    data2 = {"message" => ["Regular", "log", "message"]}
    refute LogBench::Log::Parser.cache_message?(data2), "Should not detect CACHE for regular Array message"
  end

  def test_call_stack_message_detection_with_array
    # Should detect call stack messages when message is an Array
    data1 = {"message" => ["↳", "app/controllers/users_controller.rb:10"]}
    assert LogBench::Log::Parser.call_stack_message?(data1), "Should detect call stack when message is an Array"

    data2 = {"message" => ["Regular", "log", "message"]}
    refute LogBench::Log::Parser.call_stack_message?(data2), "Should not detect call stack for regular Array message"
  end

  def test_entry_content_with_array_message
    # Entry should normalize Array messages to strings
    json_data = {"message" => ["Test", "message", "with", "array"], "timestamp" => "2025-01-01T10:00:00Z"}
    entry = LogBench::Log::Entry.new(json_data)

    assert_equal "Test message with array", entry.content
    assert_instance_of String, entry.content
  end

  # SemanticLogger tests
  def test_parse_semantic_logger_json
    collection = LogBench::Log::Collection.new([TestFixtures.semantic_logger_get_request])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_instance_of LogBench::Log::Request, request
    assert_equal "GET", request.method
    assert_equal "/users", request.path
    assert_equal 200, request.status
    assert_equal 45.2, request.duration
    assert_equal "abc123", request.request_id
  end

  def test_parse_semantic_logger_with_sql
    collection = LogBench::Log::Collection.new(TestFixtures.semantic_logger_request_with_sql)
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_equal 1, request.queries.size

    query = request.queries.first
    assert_instance_of LogBench::Log::QueryEntry, query
    assert query.select?
    assert_equal 1.2, query.duration_ms
  end

  def test_parse_semantic_logger_with_cache
    collection = LogBench::Log::Collection.new(TestFixtures.semantic_logger_request_with_cache)
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_equal 1, request.cache_operations.size

    cache_op = request.cache_operations.first
    assert_instance_of LogBench::Log::QueryEntry, cache_op
    assert cache_op.cached?
    assert cache_op.hit?
    assert_equal 0.1, cache_op.duration_ms
  end

  def test_parse_semantic_logger_with_hash_params
    collection = LogBench::Log::Collection.new([TestFixtures.semantic_logger_post_request])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first
    assert_instance_of LogBench::Log::Request, request

    # Check that params are parsed correctly
    refute_nil request.params
    assert_instance_of Hash, request.params
    assert_equal "1", request.params["id"]
    assert_equal "John Doe", request.params["user"]["name"]
    assert_equal "john@example.com", request.params["user"]["email"]
  end

  def test_semantic_logger_request_detection
    # Test that semantic_logger_request? correctly identifies SemanticLogger format
    json_data = JSON.parse(TestFixtures.semantic_logger_get_request)
    assert LogBench::Log::Parser.semantic_logger_request?(json_data)
    assert LogBench::Log::Parser.http_request?(json_data)
  end

  def test_lograge_request_detection
    # Test that lograge_request? correctly identifies lograge format
    json_data = JSON.parse(TestFixtures.lograge_get_request)
    assert LogBench::Log::Parser.lograge_request?(json_data)
    assert LogBench::Log::Parser.http_request?(json_data)
  end

  def test_semantic_logger_entry_request_id_extraction
    # Test that request_id is extracted from payload
    json_data = JSON.parse(TestFixtures.semantic_logger_get_request)
    entry = LogBench::Log::Entry.new(json_data)
    assert_equal "abc123", entry.request_id
  end

  def test_semantic_logger_named_tags_request_id_extraction
    # Test that request_id is extracted from named_tags (SemanticLogger feature)
    json_data = {
      "timestamp" => "2025-12-15T18:48:24.378004Z",
      "level" => "debug",
      "name" => "Rack",
      "message" => "Started",
      "named_tags" => {"request_id" => "named-tag-123"},
      "payload" => {"method" => "GET", "path" => "/"}
    }
    entry = LogBench::Log::Entry.new(json_data)
    assert_equal "named-tag-123", entry.request_id
  end

  def test_mixed_lograge_and_semantic_logger_parsing
    # Test that both formats can be parsed in the same collection
    mixed_logs = [
      TestFixtures.lograge_get_request,
      TestFixtures.semantic_logger_post_request
    ]
    collection = LogBench::Log::Collection.new(mixed_logs)
    requests = collection.requests

    assert_equal 2, requests.size
    assert_equal "GET", requests[0].method
    assert_equal "POST", requests[1].method
  end

  def test_configuration_logger_type_can_be_set_via_setup
    # Reset configuration to default
    LogBench.configuration = nil

    # Test setting logger_type via setup block
    LogBench.setup do |config|
      config.logger_type = :semantic_logger
    end

    assert_equal :semantic_logger, LogBench.configuration.logger_type

    # Reset to default for other tests
    LogBench.setup do |config|
      config.logger_type = :lograge
    end
  end

  def test_configuration_logger_type_defaults_to_lograge
    # Create a fresh configuration
    config = LogBench::Configuration.new

    assert_equal :lograge, config.logger_type
  end

  # Human-readable SemanticLogger converter tests
  def test_human_readable_semantic_logger_detection
    human_readable_line = "2025-11-19 23:54:33.339411 \e[36mI\e[0m [1085:33304] \e[36mRails\e[0m -- Initializing AppLabels"
    assert LogBench::Log::Parsers::SemanticLoggerParser.human_readable?(human_readable_line)

    json_line = '{"timestamp":"2025-01-01T10:00:00Z","level":"info","message":"test"}'
    refute LogBench::Log::Parsers::SemanticLoggerParser.human_readable?(json_line)
  end

  def test_convert_semantic_logger_to_json
    human_readable_line = "2025-11-19 23:54:33.339411 \e[36mI\e[0m [1085:33304] \e[36mRails\e[0m -- Initializing AppLabels"
    json_string = LogBench::Log::Parsers::SemanticLoggerParser.convert_to_json(human_readable_line)

    refute_nil json_string
    data = JSON.parse(json_string)

    assert_equal "2025-11-19 23:54:33.339411", data["timestamp"]
    assert_equal "info", data["level"]
    assert_equal "Rails", data["name"]
    assert_equal "Initializing AppLabels", data["message"]
  end

  def test_parse_human_readable_semantic_logger_line
    # Set logger type to semantic_logger for this test
    original_logger_type = LogBench.configuration&.logger_type
    LogBench.setup do |config|
      config.logger_type = :semantic_logger
    end

    human_readable_line = "2025-11-19 23:54:33.339411 \e[32mD\e[0m [1085:33304] \e[32mRails\e[0m -- Sidekiq context: false"
    entry = LogBench::Log::Parser.parse_line(human_readable_line)

    refute_nil entry
    assert_instance_of LogBench::Log::Entry, entry
    assert_equal "Sidekiq context: false", entry.content
  ensure
    # Reset logger type
    LogBench.setup do |config|
      config.logger_type = original_logger_type || :lograge
    end
  end

  def test_strip_ansi_codes
    text_with_ansi = "\e[36mRails\e[0m"
    stripped = LogBench::Log::Parsers::SemanticLoggerParser.strip_ansi_codes(text_with_ansi)

    assert_equal "Rails", stripped
  end

  def test_level_mapping_from_single_letter
    # Test Info level
    info_line = "2025-11-19 23:54:33.339411 \e[36mI\e[0m [1085:33304] \e[36mRails\e[0m -- Info message"
    json = LogBench::Log::Parsers::SemanticLoggerParser.convert_to_json(info_line)
    data = JSON.parse(json)
    assert_equal "info", data["level"]

    # Test Debug level
    debug_line = "2025-11-19 23:54:33.339411 \e[32mD\e[0m [1085:33304] \e[32mRails\e[0m -- Debug message"
    json = LogBench::Log::Parsers::SemanticLoggerParser.convert_to_json(debug_line)
    data = JSON.parse(json)
    assert_equal "debug", data["level"]

    # Test Error level
    error_line = "2025-11-19 23:54:33.339411 \e[31mE\e[0m [1085:33304] \e[31mRails\e[0m -- Error message"
    json = LogBench::Log::Parsers::SemanticLoggerParser.convert_to_json(error_line)
    data = JSON.parse(json)
    assert_equal "error", data["level"]
  end

  def test_strip_ruby_logger_wrapper
    wrapped_line = "I, [2025-11-20T15:51:32.434612 #161]  INFO -- : 2025-11-20 15:51:32.434402 [36mI[0m [161:puma] [36mRails[0m -- Test"
    stripped = LogBench::Log::Parsers::SemanticLoggerParser.strip_ruby_logger_wrapper(wrapped_line)

    assert_equal "2025-11-20 15:51:32.434402 [36mI[0m [161:puma] [36mRails[0m -- Test", stripped

    # Test with line that doesn't have wrapper
    unwrapped_line = "2025-11-20 15:51:32.434402 [36mI[0m [161:puma] [36mRails[0m -- Test"
    stripped2 = LogBench::Log::Parsers::SemanticLoggerParser.strip_ruby_logger_wrapper(unwrapped_line)
    assert_equal unwrapped_line, stripped2
  end

  def test_extract_value_from_hash
    hash_str = '{method: "GET", path: "/test", status: 200, controller: "TestController"}'

    assert_equal "GET", LogBench::Log::Parsers::SemanticLoggerParser.extract_value_from_hash(hash_str, "method")
    assert_equal "/test", LogBench::Log::Parsers::SemanticLoggerParser.extract_value_from_hash(hash_str, "path")
    assert_equal "200", LogBench::Log::Parsers::SemanticLoggerParser.extract_value_from_hash(hash_str, "status")
    assert_equal "TestController", LogBench::Log::Parsers::SemanticLoggerParser.extract_value_from_hash(hash_str, "controller")
    assert_nil LogBench::Log::Parsers::SemanticLoggerParser.extract_value_from_hash(hash_str, "nonexistent")
  end

  def test_convert_semantic_logger_completed_request
    completed_line = '2025-11-19 23:55:26.926956 [36mI[0m [1176:puma srv tp 001] {[36mrequest_id: 4e55e219-6f8e-45f0-9556-4b0bc69adbd9[0m} ([1m203.2ms[0m) [36mPortal::SessionsController[0m -- Completed #new -- {controller: "Portal::SessionsController", action: "new", method: "GET", path: "/portal/users/sign_in", status: 200}'

    json_string = LogBench::Log::Parsers::SemanticLoggerParser.send(:convert_completed_request, completed_line)
    refute_nil json_string

    data = JSON.parse(json_string)
    assert_equal "info", data["level"]
    assert_equal "Completed", data["message"]
    assert_equal 203.2, data["duration_ms"]

    payload = data["payload"]
    assert_equal "GET", payload["method"]
    assert_equal "/portal/users/sign_in", payload["path"]
    assert_equal 200, payload["status"]
    assert_equal "Portal::SessionsController", payload["controller"]
    assert_equal "new", payload["action"]
    assert_equal "4e55e219-6f8e-45f0-9556-4b0bc69adbd9", payload["request_id"]
  end

  def test_parse_wrapped_semantic_logger_completed_request
    # Set logger type
    LogBench.setup { |config| config.logger_type = :semantic_logger }

    wrapped_line = 'I, [2025-11-20T15:51:32.434612 #161]  INFO -- : 2025-11-20 15:51:32.434402 [36mI[0m [161:puma srv tp 001] {[36mrequest_id: 3044f53b-1e3a-4304-8ab0-4be35046f200[0m} ([1m24.3ms[0m) [36mDox::Frontend::AuthContext::ContextsController[0m -- Completed #show -- {controller: "Dox::Frontend::AuthContext::ContextsController", method: "GET", path: "/dox/auth/context", status: 200}'

    entry = LogBench::Log::Parser.parse_line(wrapped_line)

    refute_nil entry
    assert_instance_of LogBench::Log::Request, entry
    assert_equal "GET", entry.method
    assert_equal "/dox/auth/context", entry.path
    assert_equal 200, entry.status
    assert_equal 24.3, entry.duration
    assert_equal "3044f53b-1e3a-4304-8ab0-4be35046f200", entry.request_id
  ensure
    LogBench.setup { |config| config.logger_type = :lograge }
  end

  def test_http_request_method_detects_both_formats
    # Test lograge format
    lograge_data = {"method" => "GET", "path" => "/test", "status" => 200}
    assert LogBench::Log::Parser.http_request?(lograge_data)

    # Test semantic_logger JSON format
    semantic_data = {"payload" => {"method" => "GET", "path" => "/test", "status" => 200}}
    assert LogBench::Log::Parser.http_request?(semantic_data)

    # Test non-request data
    other_data = {"message" => "some log"}
    refute LogBench::Log::Parser.http_request?(other_data)
  end

  def test_wrapped_format_detection
    wrapped_line = "I, [2025-11-20T15:51:32.434612 #161]  INFO -- : 2025-11-20 15:51:32.434402 [36mI[0m [161:puma] [36mRails[0m -- Test"
    assert LogBench::Log::Parsers::SemanticLoggerParser.human_readable?(wrapped_line)

    unwrapped_line = "2025-11-20 15:51:32.434402 [36mI[0m [161:puma] [36mRails[0m -- Test"
    assert LogBench::Log::Parsers::SemanticLoggerParser.human_readable?(unwrapped_line)

    json_line = '{"timestamp":"2025-01-01T10:00:00Z","message":"test"}'
    refute LogBench::Log::Parsers::SemanticLoggerParser.human_readable?(json_line)
  end

  def test_duration_extraction_seconds_to_milliseconds
    # Test with seconds (should convert to ms)
    line_with_seconds = '2025-11-19 23:55:26.699664 [36mI[0m [1176:puma] {[36mrequest_id: abc123[0m} ([1m2.026s[0m) [36mController[0m -- Completed #show -- {method: "GET", path: "/test", status: 200}'

    json = LogBench::Log::Parsers::SemanticLoggerParser.send(:convert_completed_request, line_with_seconds)
    data = JSON.parse(json)

    assert_in_delta 2026.0, data["duration_ms"], 0.001
  end

  def test_request_id_extraction_from_tags
    line_with_tags = "2025-11-19 23:55:26.075679 [32mD[0m [1176:puma] {[32mrequest_id: 710d8f41-356b-4f00-8b9d-d3d341b3d145[0m, [32mmethod: GET[0m]} [32mRack[0m -- Started"

    LogBench.setup { |config| config.logger_type = :semantic_logger }
    entry = LogBench::Log::Parser.parse_line(line_with_tags)

    refute_nil entry
    assert_equal "710d8f41-356b-4f00-8b9d-d3d341b3d145", entry.request_id
  ensure
    LogBench.setup { |config| config.logger_type = :lograge }
  end
end
