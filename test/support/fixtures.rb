# frozen_string_literal: true

module TestFixtures
  def self.fixture_path(filename)
    File.join(__dir__, "..", "fixtures", filename)
  end

  def self.simple_log_path
    fixture_path("simple.log")
  end

  def self.development_log_path
    fixture_path("development.log")
  end

  def self.simple_log_lines
    File.readlines(simple_log_path, chomp: true)
  end

  def self.development_log_lines
    File.readlines(development_log_path, chomp: true)
  end

  # Individual log entries for specific tests
  def self.lograge_get_request
    '{"method":"GET","path":"/users","status":200,"duration":45.2,"controller":"UsersController","action":"index","request_id":"abc123","timestamp":"2025-01-01T10:00:00Z"}'
  end

  def self.sql_query
    '{"message":"  \u001b[1m\u001b[36mUser Load (1.2ms)\u001b[0m  \u001b[1m\u001b[34mSELECT `users`.* FROM `users` WHERE `users`.`id` = 1 LIMIT 1\u001b[0m","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}'
  end

  def self.cache_entry
    '{"message":"CACHE User Load (0.1ms)  SELECT `users`.* FROM `users` WHERE `users`.`id` = 1 LIMIT 1","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}'
  end

  def self.request_with_sql
    [lograge_get_request, sql_query]
  end

  def self.request_with_cache
    [lograge_get_request, cache_entry]
  end

  # Parameter test fixtures
  def self.lograge_request_with_hash_params
    '{"method":"POST","path":"/users","status":201,"duration":120.5,"controller":"UsersController","action":"create","params":{"id":"1","user":{"name":"John Doe","email":"john@example.com"}},"request_id":"abc456","timestamp":"2025-01-01T10:01:00Z"}'
  end

  def self.lograge_request_with_string_params
    '{"method":"PATCH","path":"/posts/5","status":200,"duration":95.7,"controller":"PostsController","action":"update","params":"{\"id\":\"5\",\"post\":{\"title\":\"Updated Title\"}}","request_id":"abc789","timestamp":"2025-01-01T10:02:00Z"}'
  end

  def self.lograge_request_with_simple_params
    '{"method":"GET","path":"/posts","status":200,"duration":78.3,"controller":"PostsController","action":"index","params":{"user_id":"1"},"request_id":"abc999","timestamp":"2025-01-01T10:03:00Z"}'
  end

  def self.lograge_request_with_invalid_json_params
    '{"method":"GET","path":"/test","status":200,"duration":50.0,"controller":"TestController","action":"show","params":"{invalid json","request_id":"abc111","timestamp":"2025-01-01T10:04:00Z"}'
  end

  def self.log_entry_with_null_message
    '{"message":null,"request_id":"abc123","timestamp":"2025-01-01T10:05:00Z"}'
  end

  def self.log_entry_with_missing_message
    '{"request_id":"abc123","timestamp":"2025-01-01T10:06:00Z"}'
  end

  def self.request_with_null_message_logs
    [lograge_get_request, log_entry_with_null_message, log_entry_with_missing_message]
  end

  # SemanticLogger fixtures
  def self.semantic_logger_get_request
    '{"name":"Rails","level":"info","message":"Completed","duration_ms":45.2,"timestamp":"2025-01-01T10:00:00Z","payload":{"method":"GET","path":"/users","status":200,"controller":"UsersController","action":"index","request_id":"abc123"}}'
  end

  def self.semantic_logger_post_request
    '{"name":"Rails","level":"info","message":"Completed","duration_ms":120.5,"timestamp":"2025-01-01T10:01:00Z","payload":{"method":"POST","path":"/users","status":201,"controller":"UsersController","action":"create","params":{"id":"1","user":{"name":"John Doe","email":"john@example.com"}},"request_id":"abc456"}}'
  end

  def self.semantic_logger_sql_query
    '{"name":"ActiveRecord","level":"debug","message":"  \u001b[1m\u001b[36mUser Load (1.2ms)\u001b[0m  \u001b[1m\u001b[34mSELECT `users`.* FROM `users` WHERE `users`.`id` = 1 LIMIT 1\u001b[0m","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}'
  end

  def self.semantic_logger_cache_entry
    '{"name":"ActiveRecord","level":"debug","message":"CACHE User Load (0.1ms)  SELECT `users`.* FROM `users` WHERE `users`.`id` = 1 LIMIT 1","request_id":"abc123","timestamp":"2025-01-01T10:00:01Z"}'
  end

  def self.semantic_logger_request_with_sql
    [semantic_logger_get_request, semantic_logger_sql_query]
  end

  def self.semantic_logger_request_with_cache
    [semantic_logger_get_request, semantic_logger_cache_entry]
  end
end
