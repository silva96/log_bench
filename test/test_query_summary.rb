require "test_helper"

class TestQuerySummary < Minitest::Test
  def setup
    # Create a request with multiple query types
    @request_lines = [
      TestFixtures.lograge_get_request,
      '{"message":"User Load (1.2ms) SELECT users.* FROM users WHERE id = 1","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}',
      '{"message":"User Update (2.3ms) UPDATE users SET last_login = NOW() WHERE id = 1","request_id":"abc123","timestamp":"2025-01-01T10:00:02Z"}',
      '{"message":"CACHE User Load (0.1ms) SELECT users.* FROM users WHERE id = 1","request_id":"abc123","timestamp":"2025-01-01T10:00:03Z"}',
      '{"message":"TRANSACTION (0.5ms) BEGIN","request_id":"abc123","timestamp":"2025-01-01T10:00:04Z"}',
      '{"message":"TRANSACTION (0.3ms) COMMIT","request_id":"abc123","timestamp":"2025-01-01T10:00:05Z"}'
    ]

    collection = LogBench::Log::Collection.new(@request_lines)
    @request = collection.requests.first
    @query_summary = LogBench::App::QuerySummary.new(@request)
  end

  def test_build_stats_counts_queries_correctly
    stats = @query_summary.build_stats

    assert_equal 5, stats[:total_queries]
    assert_equal 1, stats[:cached_queries]
    assert_equal 2, stats[:select]  # Regular SELECT + CACHE SELECT
    assert_equal 1, stats[:update]
    assert_equal 2, stats[:transaction]  # BEGIN + COMMIT
    assert_equal 0, stats[:insert]
    assert_equal 0, stats[:delete]
  end

  def test_build_stats_calculates_total_time
    stats = @query_summary.build_stats

    # Should sum up all query times: 1.2 + 2.3 + 0.1 + 0.5 + 0.3 = 4.4ms
    # Use delta for floating point comparison
    assert_in_delta 4.4, stats[:total_time], 0.01
  end

  def test_build_summary_line_with_time_and_cache
    stats = @query_summary.build_stats
    summary_line = @query_summary.build_summary_line(stats)

    assert_includes summary_line, "5 queries"
    assert_includes summary_line, "4.4ms total"
    assert_includes summary_line, "1 cached"
  end

  def test_build_summary_line_without_time
    # Create request with no timing info
    request_lines = [
      TestFixtures.lograge_get_request,
      '{"message":"SELECT users.* FROM users","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}'
    ]

    collection = LogBench::Log::Collection.new(request_lines)
    request = collection.requests.first
    query_summary = LogBench::App::QuerySummary.new(request)

    stats = query_summary.build_stats
    summary_line = query_summary.build_summary_line(stats)

    assert_includes summary_line, "1 queries"
    refute_includes summary_line, "ms total"
  end

  def test_build_breakdown_line
    stats = @query_summary.build_stats
    breakdown_line = @query_summary.build_breakdown_line(stats)

    assert_includes breakdown_line, "2 SELECT"  # Regular SELECT + CACHE SELECT
    assert_includes breakdown_line, "1 UPDATE"
    assert_includes breakdown_line, "2 TRANSACTION"
    refute_includes breakdown_line, "INSERT"
    refute_includes breakdown_line, "DELETE"
  end

  def test_build_breakdown_line_empty_when_no_queries
    # Create request with no queries
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    request = collection.requests.first
    query_summary = LogBench::App::QuerySummary.new(request)

    breakdown_line = query_summary.build_breakdown_line

    assert_equal "", breakdown_line
  end

  def test_build_text_summary_complete
    text_summary = @query_summary.build_text_summary

    lines = text_summary.split("\n")

    assert_equal "Query Summary:", lines[0]
    assert_includes lines[1], "5 queries"
    assert_includes lines[1], "4.4ms total"
    assert_includes lines[1], "1 cached"
    assert_includes lines[2], "2 SELECT, 1 UPDATE, 2 TRANSACTION"
  end

  def test_build_text_summary_no_queries
    # Create request with no queries
    collection = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    request = collection.requests.first
    query_summary = LogBench::App::QuerySummary.new(request)

    text_summary = query_summary.build_text_summary

    assert_equal "Query Summary:", text_summary
  end

  def test_categorize_sql_operation_with_query_entry
    stats = {select: 0, insert: 0, update: 0, delete: 0, transaction: 0}

    # Create a mock QueryEntry
    query_entry = Object.new
    def query_entry.is_a?(klass)
      klass == LogBench::Log::QueryEntry
    end

    def query_entry.select?
      true
    end

    def query_entry.insert?
      false
    end

    def query_entry.update?
      false
    end

    def query_entry.delete?
      false
    end

    def query_entry.transaction?
      false
    end

    def query_entry.begin?
      false
    end

    def query_entry.commit?
      false
    end

    def query_entry.rollback?
      false
    end

    def query_entry.savepoint?
      false
    end

    @query_summary.send(:categorize_sql_operation, query_entry, stats)

    assert_equal 1, stats[:select]
    assert_equal 0, stats[:insert]
  end

  def test_categorize_sql_operation_with_non_query_entry
    stats = {select: 0, insert: 0, update: 0, delete: 0, transaction: 0}

    # Create a mock non-QueryEntry
    regular_entry = Object.new
    def regular_entry.is_a?(klass)
      false
    end

    @query_summary.send(:categorize_sql_operation, regular_entry, stats)

    # Stats should remain unchanged
    assert_equal 0, stats[:select]
    assert_equal 0, stats[:insert]
  end

  def test_handles_transaction_operations
    # Test all transaction-related operations
    transaction_lines = [
      TestFixtures.lograge_get_request,
      '{"message":"TRANSACTION (0.1ms) BEGIN","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}',
      '{"message":"TRANSACTION (0.1ms) COMMIT","request_id":"abc123","timestamp":"2025-01-01T10:00:02Z"}',
      '{"message":"TRANSACTION (0.1ms) ROLLBACK","request_id":"abc123","timestamp":"2025-01-01T10:00:03Z"}',
      '{"message":"TRANSACTION (0.1ms) SAVEPOINT","request_id":"abc123","timestamp":"2025-01-01T10:00:04Z"}'
    ]

    collection = LogBench::Log::Collection.new(transaction_lines)
    request = collection.requests.first
    query_summary = LogBench::App::QuerySummary.new(request)

    stats = query_summary.build_stats

    # All transaction operations should be counted as transactions
    assert_equal 4, stats[:transaction]
    assert_equal 4, stats[:total_queries]
  end
end
