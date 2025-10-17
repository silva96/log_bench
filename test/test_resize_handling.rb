# frozen_string_literal: true

require "test_helper"

class TestResizeHandling < Minitest::Test
  def setup
    @screen = LogBench::App::Screen.new
    @state = test_state
    @renderer = LogBench::App::Renderer::Main.new(@screen, @state, "test.log")
    @input_handler = LogBench::App::InputHandler.new(@state, @screen, @renderer)
  end

  def test_screen_has_handle_resize_method
    assert_respond_to @screen, :handle_resize
  end

  def test_renderer_has_invalidate_caches_method
    assert_respond_to @renderer, :invalidate_caches
  end

  def test_details_renderer_has_invalidate_cache_method
    details_renderer = @renderer.instance_variable_get(:@details)
    assert_respond_to details_renderer, :invalidate_cache
  end

  def test_input_handler_has_handle_resize_method
    assert_respond_to @input_handler, :handle_resize
  end

  def test_handle_resize_calls_screen_and_renderer
    # Mock the screen and renderer methods
    screen_resize_called = false
    renderer_invalidate_called = false

    @screen.define_singleton_method(:handle_resize) do
      screen_resize_called = true
    end

    @renderer.define_singleton_method(:invalidate_caches) do
      renderer_invalidate_called = true
    end

    # Call handle_resize on input handler
    @input_handler.send(:handle_resize)

    assert screen_resize_called, "Screen handle_resize should be called"
    assert renderer_invalidate_called, "Renderer invalidate_caches should be called"
  end

  def test_details_invalidate_cache_clears_cached_data
    details_renderer = @renderer.instance_variable_get(:@details)

    # Set some cached data
    details_renderer.instance_variable_set(:@cached_lines, ["test"])
    details_renderer.instance_variable_set(:@cache_key, "test_key")

    # Call invalidate_cache
    details_renderer.invalidate_cache

    # Verify cache is cleared
    assert_nil details_renderer.instance_variable_get(:@cached_lines)
    assert_nil details_renderer.instance_variable_get(:@cache_key)
  end
end
