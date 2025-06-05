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
end
