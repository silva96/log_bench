# frozen_string_literal: true

require "test_helper"

class TestSortToggle < Minitest::Test
  def setup
    @state = test_state
    collection = LogBench::Log::Collection.new(TestFixtures.simple_log_lines)
    @state.requests = collection.requests
  end

  def test_toggle_status_sort_direction
    @state.toggle_request_sort(:status)

    assert_equal "↓", @state.sort_arrow_for_column(:status)
    assert_equal 201, @state.filtered_requests.first.status

    @state.toggle_request_sort(:status)

    assert_equal "↑", @state.sort_arrow_for_column(:status)
    assert_equal 200, @state.filtered_requests.first.status

    @state.toggle_request_sort(:status)

    assert_nil @state.sort_arrow_for_column(:status)
    assert_equal "TIMESTAMP ASC", @state.sort.display_name
  end

  def test_toggle_time_sort_direction
    max_duration = @state.requests.map(&:duration).max
    min_duration = @state.requests.map(&:duration).min

    @state.toggle_request_sort(:time)

    assert_equal "↓", @state.sort_arrow_for_column(:time)
    assert_equal max_duration, @state.filtered_requests.first.duration

    @state.toggle_request_sort(:time)

    assert_equal "↑", @state.sort_arrow_for_column(:time)
    assert_equal min_duration, @state.filtered_requests.first.duration

    @state.toggle_request_sort(:time)

    assert_nil @state.sort_arrow_for_column(:time)
    assert_equal "TIMESTAMP ASC", @state.sort.display_name
  end

  def test_path_sort_is_ignored
    initial_display_name = @state.sort.display_name

    @state.toggle_request_sort(:path)

    assert_equal initial_display_name, @state.sort.display_name
    assert_nil @state.sort_arrow_for_column(:path)
  end
end
