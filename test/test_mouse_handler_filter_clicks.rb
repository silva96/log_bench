# frozen_string_literal: true

require "test_helper"

class TestMouseHandlerFilterClicks < Minitest::Test
  TestScreen = Struct.new(:panel_width)

  def setup
    @state = test_state
    collection = LogBench::Log::Collection.new(TestFixtures.simple_log_lines)
    @state.requests = collection.requests
    @screen = TestScreen.new(50)
    @mouse_handler = LogBench::App::MouseHandler.new(@state, @screen)
  end

  def test_clicking_filter_row_selects_column_and_enters_filter_mode
    @state.switch_to_right_pane
    refute @state.filter_mode

    # y = 5 (header) + 2 (RequestList::FILTER_ROW_Y)
    status_x = @screen.panel_width - 13
    @mouse_handler.send(:handle_mouse_click, status_x, 7)

    assert @state.left_pane_focused?
    assert @state.filter_mode
    assert_equal :status, @state.active_request_filter_column
  end

  def test_clicking_time_filter_area_selects_time_column
    @state.switch_to_right_pane
    refute @state.filter_mode

    # y = 5 (header) + 2 (RequestList::FILTER_ROW_Y)
    time_x = @screen.panel_width - 3
    @mouse_handler.send(:handle_mouse_click, time_x, 7)

    assert @state.left_pane_focused?
    assert @state.filter_mode
    assert_equal :time, @state.active_request_filter_column
  end

  def test_clicking_first_request_row_selects_request
    @state.selected = 1

    # y = 5 (header) + 3 (RequestList::ROWS_START_Y)
    @mouse_handler.send(:handle_mouse_click, 10, 8)

    assert_equal 0, @state.selected
  end

  def test_clicking_second_request_row_selects_second_request
    @state.selected = 0

    # second request row is first request row + 1
    @mouse_handler.send(:handle_mouse_click, 10, 9)

    assert_equal 1, @state.selected
  end
end
