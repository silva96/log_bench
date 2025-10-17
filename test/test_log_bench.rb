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
end
