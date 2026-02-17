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

    assert_equal "a", @state.main_filter.display_text
  end

  def test_backspace_ctrl_h_removes_character
    @input_handler.send(:handle_filter_input, 8)

    assert_equal "a", @state.main_filter.display_text
  end

  def test_backspace_key_backspace_removes_character
    @input_handler.send(:handle_filter_input, Curses::KEY_BACKSPACE)

    assert_equal "a", @state.main_filter.display_text
  end
end
