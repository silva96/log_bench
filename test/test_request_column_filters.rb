# frozen_string_literal: true

require "test_helper"

class TestRequestColumnFilters < Minitest::Test
  def setup
    @state = test_state
    collection = LogBench::Log::Collection.new(TestFixtures.simple_log_lines)
    @state.requests = collection.requests
  end

  def test_filters_by_status_comparison
    set_filter(:status, ">200")

    filtered = @state.filtered_requests
    assert_equal 1, filtered.size
    assert_equal 201, filtered.first.status
  end

  def test_filters_by_time_comparison
    set_filter(:time, "<100")

    filtered = @state.filtered_requests
    assert_equal 1, filtered.size
    assert_equal "GET", filtered.first.method
  end

  def test_filters_by_numeric_range
    set_filter(:status, "200-200")

    filtered = @state.filtered_requests
    assert_equal 1, filtered.size
    assert_equal 200, filtered.first.status
  end

  def test_ignores_operator_only_filter_for_status
    set_filter(:status, ">")
    assert_equal 2, @state.filtered_requests.size

    set_filter(:status, "<=")
    assert_equal 2, @state.filtered_requests.size
  end

  def test_ignores_operator_only_filter_for_time
    set_filter(:time, "<")
    assert_equal 2, @state.filtered_requests.size

    set_filter(:time, ">=")
    assert_equal 2, @state.filtered_requests.size
  end

  def test_applies_multiple_column_filters
    set_filter(:method, "post")
    set_filter(:time, ">=120")

    filtered = @state.filtered_requests
    assert_equal 1, filtered.size
    assert_equal "POST", filtered.first.method
    assert_operator filtered.first.duration, :>=, 120
  end

  def test_clear_filter_clears_all_request_column_filters
    @state.switch_to_left_pane
    set_filter(:method, "get")
    set_filter(:time, ">10")
    assert @state.request_filters_present?

    @state.clear_filter

    refute @state.request_filters_present?
    assert_equal 2, @state.filtered_requests.size
  end

  private

  def set_filter(column, expression)
    filter = @state.request_filter_for(column)
    filter.clear
    expression.each_char { |char| filter.add_character(char) }
  end
end
