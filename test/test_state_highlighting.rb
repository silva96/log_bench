# frozen_string_literal: true

require "test_helper"

class TestStateHighlighting < Minitest::Test
  def setup
    @state = test_state

    # Create test requests
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_sql)
    @state.requests = collection.requests
    @state.selected = 0
  end

  def test_detail_selected_entry_defaults_to_zero
    assert_equal 0, @state.detail_selected_entry
  end

  def test_navigate_up_in_detail_pane
    @state.switch_to_right_pane
    @state.detail_selected_entry = 2

    @state.navigate_up

    assert_equal 1, @state.detail_selected_entry
  end

  def test_navigate_up_in_detail_pane_at_minimum
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    @state.navigate_up

    # Should stay at 0 (minimum)
    assert_equal 0, @state.detail_selected_entry
  end

  def test_navigate_down_in_detail_pane
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    @state.navigate_down

    assert_equal 1, @state.detail_selected_entry
  end

  def test_reset_detail_selection
    @state.detail_selected_entry = 5
    @state.detail_scroll_offset = 10

    @state.reset_detail_selection

    assert_equal 0, @state.detail_selected_entry
    assert_equal 0, @state.detail_scroll_offset
  end

  def test_adjust_detail_scroll_for_entry_selection_with_valid_entry
    @state.switch_to_right_pane
    @state.detail_selected_entry = 1
    @state.detail_scroll_offset = 0

    # Mock lines with entry_ids
    lines = [
      {text: "Line 1", entry_id: 1},
      {text: "Line 2", entry_id: 1},
      {text: "Line 3", entry_id: 2},
      {text: "Line 4", entry_id: 2},
      {text: "Line 5", entry_id: 3}
    ]

    visible_height = 3

    @state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

    # Should adjust scroll to show the selected entry
    assert @state.detail_scroll_offset >= 0
  end

  def test_adjust_detail_scroll_for_entry_selection_excludes_separator_lines
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    # Mock lines with separators
    lines = [
      {text: "Line 1", entry_id: 1},
      {text: "", separator: true},
      {text: "Line 2", entry_id: 2},
      {text: "Line 3", entry_id: 2}
    ]

    visible_height = 3

    @state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

    # Should work correctly even with separator lines
    assert @state.detail_scroll_offset >= 0
  end

  def test_adjust_detail_scroll_for_entry_selection_clamps_selection
    @state.switch_to_right_pane
    @state.detail_selected_entry = 999  # Way too high

    lines = [
      {text: "Line 1", entry_id: 1},
      {text: "Line 2", entry_id: 2}
    ]

    visible_height = 3

    @state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

    # Should clamp to valid range (0-1 for 2 unique entries)
    assert @state.detail_selected_entry <= 1
    assert @state.detail_selected_entry >= 0
  end

  def test_adjust_detail_scroll_for_entry_selection_scrolls_to_show_first_line
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0
    @state.detail_scroll_offset = 5  # Scrolled past the selected entry

    lines = [
      {text: "Line 1", entry_id: 1},  # Index 0 - selected entry
      {text: "Line 2", entry_id: 1},
      {text: "Line 3", entry_id: 2},
      {text: "Line 4", entry_id: 2},
      {text: "Line 5", entry_id: 3},
      {text: "Line 6", entry_id: 3}
    ]

    visible_height = 3

    @state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

    # Should scroll up to show the first line of selected entry
    assert @state.detail_scroll_offset <= 0
  end

  def test_adjust_detail_scroll_for_entry_selection_scrolls_to_show_last_line
    @state.switch_to_right_pane
    @state.detail_selected_entry = 1  # Second entry
    @state.detail_scroll_offset = 0

    lines = [
      {text: "Line 1", entry_id: 1},
      {text: "Line 2", entry_id: 2},  # Index 1 - first line of selected entry
      {text: "Line 3", entry_id: 2},  # Index 2
      {text: "Line 4", entry_id: 2},  # Index 3 - last line of selected entry
      {text: "", separator: true},    # Index 4 - separator after entry
      {text: "Line 5", entry_id: 3}
    ]

    visible_height = 2  # Can only show 2 lines

    @state.adjust_detail_scroll_for_entry_selection(visible_height, lines)

    # Should scroll down to show the complete entry
    # Last line of entry (including separator) is at index 4
    # With visible_height=2, scroll should be at least 3 to show lines 3-4
    assert @state.detail_scroll_offset >= 3
  end

  def test_adjust_detail_scroll_only_when_right_pane_focused
    @state.switch_to_left_pane  # Left pane focused
    @state.detail_selected_entry = 0
    original_scroll = @state.detail_scroll_offset = 5

    lines = [{text: "Line 1", entry_id: 1}]

    @state.adjust_detail_scroll_for_entry_selection(3, lines)

    # Should not change scroll when left pane is focused
    assert_equal original_scroll, @state.detail_scroll_offset
  end

  def test_pane_focus_switching
    # Default should be left pane
    assert @state.left_pane_focused?
    refute @state.right_pane_focused?

    @state.switch_to_right_pane

    refute @state.left_pane_focused?
    assert @state.right_pane_focused?

    @state.switch_to_left_pane

    assert @state.left_pane_focused?
    refute @state.right_pane_focused?
  end
end
