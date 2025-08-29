# frozen_string_literal: true

require "test_helper"

class TestClipboard < Minitest::Test
  def test_copy_class_method
    # Test that the class method delegates to instance method
    test_text = "Hello, World!"

    # Mock the instance method
    clipboard_instance = LogBench::App::Clipboard.new
    clipboard_instance.stub(:copy, ->(text) { assert_equal test_text, text }) do
      LogBench::App::Clipboard.stub(:new, clipboard_instance) do
        LogBench::App::Clipboard.copy(test_text)
      end
    end
  end

  def test_copy_with_pbcopy_available
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"

    # Mock system check to return true for pbcopy
    clipboard.stub(:system, ->(cmd) { cmd.include?("pbcopy") }) do
      # Mock IO.popen to capture the text being written
      written_text = nil
      IO.stub(:popen, ->(cmd, mode, &block) {
        if cmd == "pbcopy" && mode == "w"
          io_mock = Object.new
          def io_mock.write(text)
            @written_text = text
          end

          def io_mock.written_text
            @written_text
          end

          block.call(io_mock)
          written_text = io_mock.written_text
        end
      }) do
        clipboard.copy(test_text)
      end

      assert_equal test_text, written_text
    end
  end

  def test_copy_with_xclip_available
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"

    # Mock system check to return false for pbcopy, true for xclip
    system_calls = []
    clipboard.stub(:system, ->(cmd) {
      system_calls << cmd
      cmd.include?("xclip")
    }) do
      # Mock IO.popen for xclip
      written_text = nil
      IO.stub(:popen, ->(cmd, mode, &block) {
        if cmd == "xclip -selection clipboard" && mode == "w"
          io_mock = Object.new
          def io_mock.write(text)
            @written_text = text
          end

          def io_mock.written_text
            @written_text
          end

          block.call(io_mock)
          written_text = io_mock.written_text
        end
      }) do
        clipboard.copy(test_text)
      end

      assert_equal test_text, written_text
      assert_includes system_calls, "which pbcopy > /dev/null 2>&1"
      assert_includes system_calls, "which xclip > /dev/null 2>&1"
    end
  end

  def test_copy_with_xsel_available
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"

    # Mock system check to return false for pbcopy and xclip, true for xsel
    system_calls = []
    clipboard.stub(:system, ->(cmd) {
      system_calls << cmd
      cmd.include?("xsel")
    }) do
      # Mock IO.popen for xsel
      written_text = nil
      IO.stub(:popen, ->(cmd, mode, &block) {
        if cmd == "xsel --clipboard --input" && mode == "w"
          io_mock = Object.new
          def io_mock.write(text)
            @written_text = text
          end

          def io_mock.written_text
            @written_text
          end

          block.call(io_mock)
          written_text = io_mock.written_text
        end
      }) do
        clipboard.copy(test_text)
      end

      assert_equal test_text, written_text
      assert_includes system_calls, "which pbcopy > /dev/null 2>&1"
      assert_includes system_calls, "which xclip > /dev/null 2>&1"
      assert_includes system_calls, "which xsel > /dev/null 2>&1"
    end
  end

  def test_copy_fallback_to_temp_file
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"
    temp_file_path = "/tmp/logbench_copy.txt"

    # Mock system check to return false for all clipboard tools
    clipboard.stub(:system, false) do
      # Mock File.write to capture the fallback
      written_files = {}
      File.stub(:write, ->(path, content) { written_files[path] = content }) do
        clipboard.copy(test_text)
      end

      assert_equal test_text, written_files[temp_file_path]
    end
  end

  def test_copy_handles_exceptions_gracefully
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"

    # Mock system to raise an exception
    clipboard.stub(:system, ->(_cmd) { raise StandardError, "Command failed" }) do
      # Should not raise an exception
      clipboard.copy(test_text)
      # If we get here, no exception was raised
      assert true
    end
  end

  def test_copy_handles_io_exceptions_gracefully
    clipboard = LogBench::App::Clipboard.new
    test_text = "Test clipboard content"

    # Mock system check to return true for pbcopy
    clipboard.stub(:system, ->(cmd) { cmd.include?("pbcopy") }) do
      # Mock IO.popen to raise an exception
      IO.stub(:popen, ->(_cmd, _mode, &_block) { raise IOError, "IO failed" }) do
        # Should not raise an exception
        clipboard.copy(test_text)
        # If we get here, no exception was raised
        assert true
      end
    end
  end

  def test_copy_with_empty_text
    clipboard = LogBench::App::Clipboard.new

    # Mock system check to return true for pbcopy
    clipboard.stub(:system, ->(cmd) { cmd.include?("pbcopy") }) do
      # Mock IO.popen to capture empty text
      written_text = nil
      IO.stub(:popen, ->(cmd, mode, &block) {
        if cmd == "pbcopy" && mode == "w"
          io_mock = Object.new
          def io_mock.write(text)
            @written_text = text
          end

          def io_mock.written_text
            @written_text
          end

          block.call(io_mock)
          written_text = io_mock.written_text
        end
      }) do
        clipboard.copy("")
      end

      assert_equal "", written_text
    end
  end

  def test_copy_with_multiline_text
    clipboard = LogBench::App::Clipboard.new
    test_text = "Line 1\nLine 2\nLine 3"

    # Mock system check to return true for pbcopy
    clipboard.stub(:system, ->(cmd) { cmd.include?("pbcopy") }) do
      # Mock IO.popen to capture multiline text
      written_text = nil
      IO.stub(:popen, ->(cmd, mode, &block) {
        if cmd == "pbcopy" && mode == "w"
          io_mock = Object.new
          def io_mock.write(text)
            @written_text = text
          end

          def io_mock.written_text
            @written_text
          end

          block.call(io_mock)
          written_text = io_mock.written_text
        end
      }) do
        clipboard.copy(test_text)
      end

      assert_equal test_text, written_text
      assert_includes written_text, "\n"
    end
  end
end
