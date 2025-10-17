# frozen_string_literal: true

require "test_helper"

class TestClearRequests < Minitest::Test
  def setup
    @state = test_state

    # Create test requests
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_sql)
    @state.requests = collection.requests
    @state.selected = 0
  end

  def test_clear_requests_empties_requests_array
    original_requests = @state.requests.dup
    refute_empty @state.requests

    @state.clear_requests

    assert_empty @state.requests
    assert_equal original_requests, @state.cleared_requests[:requests]
  end

  def test_clear_requests_stores_current_state
    @state.selected = 5
    @state.scroll_offset = 10
    @state.detail_scroll_offset = 3
    @state.detail_selected_entry = 2

    @state.clear_requests

    # Should reset current state to 0
    assert_equal 0, @state.selected
    assert_equal 0, @state.scroll_offset
    assert_equal 0, @state.detail_scroll_offset
    assert_equal 0, @state.detail_selected_entry

    # Should store previous state
    assert_equal 5, @state.cleared_requests[:selected]
    assert_equal 10, @state.cleared_requests[:scroll_offset]
    assert_equal 3, @state.cleared_requests[:detail_scroll_offset]
    assert_equal 2, @state.cleared_requests[:detail_selected_entry]
  end

  def test_undo_clear_requests_restores_requests_and_state
    original_requests = @state.requests.dup
    @state.selected = 3
    @state.scroll_offset = 7
    @state.detail_scroll_offset = 2
    @state.detail_selected_entry = 1

    @state.clear_requests

    assert_empty @state.requests
    assert @state.can_undo_clear?

    @state.undo_clear_requests

    assert_equal original_requests, @state.requests
    assert_equal 3, @state.selected
    assert_equal 7, @state.scroll_offset
    assert_equal 2, @state.detail_scroll_offset
    assert_equal 1, @state.detail_selected_entry
    assert_nil @state.cleared_requests
    refute @state.can_undo_clear?
  end

  def test_undo_clear_requests_ignores_changes_after_clear
    # Set initial state
    @state.selected = 2
    @state.scroll_offset = 5

    @state.clear_requests

    # Simulate some state changes after clear (these should be ignored)
    @state.selected = 10
    @state.scroll_offset = 15

    @state.undo_clear_requests

    # Should restore original state, not the state after clear
    assert_equal 2, @state.selected
    assert_equal 5, @state.scroll_offset
    assert_equal 0, @state.detail_scroll_offset
    assert_equal 0, @state.detail_selected_entry
  end

  def test_undo_clear_requests_when_no_cleared_requests
    # Should not crash when there are no cleared requests
    refute @state.can_undo_clear?

    @state.undo_clear_requests

    # Should remain unchanged
    refute_empty @state.requests
    refute @state.can_undo_clear?
  end

  def test_can_undo_clear_returns_correct_state
    refute @state.can_undo_clear?

    @state.clear_requests
    assert @state.can_undo_clear?

    @state.undo_clear_requests
    refute @state.can_undo_clear?
  end

  def test_multiple_clears_concatenates_all_requests
    original_requests = @state.requests.dup
    @state.selected = 1
    @state.scroll_offset = 3

    # First clear
    @state.clear_requests

    # Add new requests after first clear
    collection2 = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    new_requests = collection2.requests
    @state.requests = new_requests
    @state.selected = 2
    @state.scroll_offset = 6

    # Second clear - should concatenate with previously cleared requests
    @state.clear_requests

    # Should store all requests: original + new from after first clear
    expected_requests = original_requests + new_requests
    assert_equal expected_requests, @state.cleared_requests[:requests]
    assert_equal expected_requests.size, @state.cleared_requests[:requests].size

    # Should preserve the state from the FIRST clear (not the second)
    assert_equal 1, @state.cleared_requests[:selected]
    assert_equal 3, @state.cleared_requests[:scroll_offset]

    # Verify the order: original requests first, then new ones
    assert_equal original_requests.first.request_id, @state.cleared_requests[:requests].first.request_id
    assert_equal new_requests.first.request_id, @state.cleared_requests[:requests].last.request_id
  end

  def test_undo_clear_preserves_stored_state_exactly
    # Set up a specific state
    @state.selected = 3
    @state.scroll_offset = 12
    @state.detail_scroll_offset = 5
    @state.detail_selected_entry = 2

    original_requests = @state.requests.dup

    @state.clear_requests

    # Verify the exact state was stored
    stored_state = @state.cleared_requests
    assert_equal original_requests, stored_state[:requests]
    assert_equal 3, stored_state[:selected]
    assert_equal 12, stored_state[:scroll_offset]
    assert_equal 5, stored_state[:detail_scroll_offset]
    assert_equal 2, stored_state[:detail_selected_entry]

    @state.undo_clear_requests

    # Verify exact restoration (no new requests in this test)
    assert_equal original_requests, @state.requests
    assert_equal 3, @state.selected
    assert_equal 12, @state.scroll_offset
    assert_equal 5, @state.detail_scroll_offset
    assert_equal 2, @state.detail_selected_entry
  end

  def test_undo_clear_appends_new_requests_to_restored_ones
    original_requests = @state.requests.dup
    @state.selected = 1
    @state.scroll_offset = 3

    @state.clear_requests

    # Simulate new requests coming in after clear
    new_collection = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    new_requests = new_collection.requests
    @state.requests = new_requests

    @state.undo_clear_requests

    # Should have original requests + new requests
    expected_requests = original_requests + new_requests
    assert_equal expected_requests, @state.requests
    assert_equal expected_requests.size, @state.requests.size

    # Should restore original position
    assert_equal 1, @state.selected
    assert_equal 3, @state.scroll_offset

    # Verify the order: original requests first, then new ones
    assert_equal original_requests.first.request_id, @state.requests.first.request_id
    assert_equal new_requests.first.request_id, @state.requests.last.request_id
  end

  def test_undo_clear_with_no_new_requests_after_clear
    original_requests = @state.requests.dup
    @state.selected = 2

    @state.clear_requests
    # No new requests added after clear

    @state.undo_clear_requests

    # Should just restore original requests
    assert_equal original_requests, @state.requests
    assert_equal 2, @state.selected
  end

  def test_three_consecutive_clears_preserves_all_requests
    # Start with initial requests
    initial_requests = @state.requests.dup
    @state.clear_requests

    # Add batch 1 and clear again
    collection1 = LogBench::Log::Collection.new([TestFixtures.lograge_get_request])
    batch1_requests = collection1.requests
    @state.requests = batch1_requests
    @state.clear_requests

    # Add batch 2 and clear again
    collection2 = LogBench::Log::Collection.new([TestFixtures.lograge_request_with_hash_params])
    batch2_requests = collection2.requests
    @state.requests = batch2_requests
    @state.clear_requests

    # Should have all three batches stored
    expected_requests = initial_requests + batch1_requests + batch2_requests
    assert_equal expected_requests, @state.cleared_requests[:requests]
    assert_equal expected_requests.size, @state.cleared_requests[:requests].size

    # Verify order: initial, then batch1, then batch2
    assert_equal initial_requests.first.request_id, @state.cleared_requests[:requests].first.request_id
    assert_equal batch2_requests.first.request_id, @state.cleared_requests[:requests].last.request_id
  end
end
