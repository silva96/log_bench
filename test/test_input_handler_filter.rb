# frozen_string_literal: true

require "test_helper"

class TestInputHandlerFilter < Minitest::Test
  def setup
    @state = test_state
    @state.switch_to_left_pane
    @state.enter_filter_mode
    @state.add_to_filter("ab")
    @input_handler = LogBench::App::InputHandler.new(@state, Object.new)
  end

  def test_backspace_ascii_127_removes_character
    @input_handler.send(:handle_filter_input, 127)

    assert_equal "a", @state.request_filter_for(:path).display_text
  end

  def test_backspace_ctrl_h_removes_character
    @input_handler.send(:handle_filter_input, 8)

    assert_equal "a", @state.request_filter_for(:path).display_text
  end

  def test_backspace_key_backspace_removes_character
    @input_handler.send(:handle_filter_input, Curses::KEY_BACKSPACE)

    assert_equal "a", @state.request_filter_for(:path).display_text
  end

  def test_right_arrow_switches_active_request_filter_column
    assert_equal :path, @state.active_request_filter_column

    @input_handler.send(:handle_filter_input, Curses::KEY_RIGHT)

    assert_equal :status, @state.active_request_filter_column
  end

  def test_left_arrow_switches_active_request_filter_column
    assert_equal :path, @state.active_request_filter_column

    @input_handler.send(:handle_filter_input, Curses::KEY_LEFT)

    assert_equal :method, @state.active_request_filter_column
  end

  def test_shift_tab_switches_active_request_filter_column_backwards
    assert_equal :path, @state.active_request_filter_column

    @input_handler.send(:handle_filter_input, 353)

    assert_equal :method, @state.active_request_filter_column
  end

  def test_tab_cycles_active_request_filter_column
    @state.select_request_filter_column(:time)

    @input_handler.send(:handle_filter_input, 9)

    assert_equal :method, @state.active_request_filter_column
  end
end
