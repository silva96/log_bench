# frozen_string_literal: true

require "test_helper"

class TestCopyHandler < Minitest::Test
  def setup
    @state = test_state
    @renderer = MockRenderer.new
    @copy_handler = LogBench::App::CopyHandler.new(@state, @renderer)

    # Create a test request with related logs
    collection = LogBench::Log::Collection.new(TestFixtures.request_with_sql)
    @request = collection.requests.first
    @state.requests = [@request]
    @state.selected = 0
  end

  def test_copy_selected_request_basic_info
    @state.switch_to_left_pane

    # Mock clipboard to capture what gets copied
    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    refute_nil copied_content
    assert_includes copied_content, "GET /users 200"
    assert_includes copied_content, "Duration: 45.2ms"
    assert_includes copied_content, "Controller: UsersController"
    assert_includes copied_content, "Action: index"
    assert_includes copied_content, "Request ID: abc123"
  end

  def test_copy_selected_request_with_query_summary
    @state.switch_to_left_pane

    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    # Should include query summary
    assert_includes copied_content, "Query Summary:"
    assert_includes copied_content, "1 queries"
    assert_includes copied_content, "1 SELECT"
  end

  def test_copy_selected_request_markdown_formatting
    @state.switch_to_left_pane

    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    # Should be wrapped in markdown code blocks
    assert copied_content.start_with?("```")
    assert copied_content.end_with?("```")
  end

  def test_copy_selected_detail_entry_sql_query
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    # Mock renderer to return test lines
    @renderer.mock_lines = [
      {text: "User Load (1.2ms) SELECT users.* FROM users WHERE id = 1", entry_id: 1},
      {text: "app/controllers/users_controller.rb:10:in `show'", entry_id: 1}
    ]

    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    # Should detect SQL and wrap in SQL markdown
    assert copied_content.start_with?("```sql")
    assert copied_content.end_with?("```")
    assert_includes copied_content, "SELECT users.* FROM users"
    assert_includes copied_content, "app/controllers/users_controller.rb"
  end

  def test_copy_selected_detail_entry_non_sql
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    # Mock renderer to return non-SQL lines
    @renderer.mock_lines = [
      {text: "Processing by UsersController#show", entry_id: 1},
      {text: "Parameters: {\"id\"=>\"1\"}", entry_id: 1}
    ]

    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    # Should not wrap in SQL markdown for non-SQL content
    refute copied_content.start_with?("```sql")
    assert_includes copied_content, "Processing by UsersController#show"
    assert_includes copied_content, "Parameters:"
  end

  def test_sql_query_detection
    # Test SQL keyword detection
    assert @copy_handler.send(:sql_query?, "SELECT * FROM users")
    assert @copy_handler.send(:sql_query?, "User Load (1.2ms) INSERT INTO users")
    assert @copy_handler.send(:sql_query?, "UPDATE users SET name = 'test'")
    assert @copy_handler.send(:sql_query?, "DELETE FROM users WHERE id = 1")
    assert @copy_handler.send(:sql_query?, "TRANSACTION (0.1ms) BEGIN")

    # Test non-SQL content
    refute @copy_handler.send(:sql_query?, "Processing by UsersController")
    refute @copy_handler.send(:sql_query?, "Parameters: {id: 1}")
    refute @copy_handler.send(:sql_query?, "Completed 200 OK")
  end

  def test_copy_strips_ansi_codes
    @state.switch_to_right_pane
    @state.detail_selected_entry = 0

    # Mock renderer with ANSI codes
    @renderer.mock_lines = [
      {text: "\e[1m\e[36mUser Load (1.2ms)\e[0m SELECT users.*", entry_id: 1}
    ]

    copied_content = nil
    LogBench::App::Clipboard.stub(:copy, ->(content) { copied_content = content }) do
      @copy_handler.copy_to_clipboard
    end

    # Should strip ANSI codes
    refute_includes copied_content, "\e[1m"
    refute_includes copied_content, "\e[36m"
    refute_includes copied_content, "\e[0m"
    assert_includes copied_content, "User Load (1.2ms) SELECT users.*"
  end

  private

  # Mock renderer for testing
  class MockRenderer
    attr_accessor :mock_lines

    def initialize
      @mock_lines = []
    end

    def get_cached_detail_lines(request)
      @mock_lines
    end
  end
end
