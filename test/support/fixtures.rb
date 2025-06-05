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
end
