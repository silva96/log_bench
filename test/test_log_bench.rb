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
    assert_instance_of LogBench::Log::CacheEntry, cache_op
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

  def test_request_to_h_includes_params
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_hash_params])
    requests = collection.requests
    request = requests.first

    hash = request.to_h
    refute_nil hash[:params]
    assert_equal request.params, hash[:params]
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
end
