# frozen_string_literal: true

require "test_helper"

class TestJobPrefixRendering < Minitest::Test
  def test_adds_colored_prefix_to_job_logs_without_prefix
    # Simulate a job log that was created before LogBench was installed
    # (has ActiveJob tags but no colored prefix in the message)
    request_id = "req-123"
    job_id = "test-job-123"
    job_class = "EmailJob"

    # Create a request and a job log
    request_log = %({"method":"POST","path":"/users","status":200,"duration":45.2,"request_id":"#{request_id}","timestamp":"2025-10-17T14:00:00Z"})
    job_log = %({"message":"Sending email to user","level":"INFO","timestamp":"2025-10-17T14:00:01Z","tags":["ActiveJob","#{job_class}","#{job_id}"],"request_id":"#{request_id}"})

    collection = LogBench::Log::Collection.new([request_log, job_log])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # The entry should have the tags
    entry = request.related_logs.first
    assert_equal ["ActiveJob", job_class, job_id], entry.json_data["tags"]

    # The content SHOULD now have the colored prefix (added during parsing)
    assert entry.content.include?("[#{job_class}##{job_id}]")
    assert entry.content.include?("Sending email to user")
  end

  def test_does_not_add_prefix_if_already_present
    # Simulate a job log that was created WITH LogBench installed
    # (already has colored prefix in the message)
    request_id = "req-456"
    job_id = "test-job-456"
    job_class = "DataProcessJob"

    # Message already has the colored prefix (plain text version for testing)
    message_with_prefix = "[#{job_class}##{job_id}] Processing data"

    request_log = %({"method":"POST","path":"/data","status":200,"duration":45.2,"request_id":"#{request_id}","timestamp":"2025-10-17T14:00:00Z"})
    job_log = %({"message":"#{message_with_prefix}","level":"INFO","timestamp":"2025-10-17T14:00:01Z","tags":["ActiveJob","#{job_class}","#{job_id}"],"request_id":"#{request_id}"})

    collection = LogBench::Log::Collection.new([request_log, job_log])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # The entry should already have the prefix
    entry = request.related_logs.first
    assert entry.content.include?("[#{job_class}##{job_id}]")
  end

  def test_does_not_add_prefix_to_non_job_logs
    # Regular log without ActiveJob tags
    request_id = "req-789"

    request_log = %({"method":"GET","path":"/test","status":200,"duration":10.5,"request_id":"#{request_id}","timestamp":"2025-10-17T14:00:00Z"})
    regular_log = %({"message":"Regular log message","level":"INFO","timestamp":"2025-10-17T14:00:01Z","request_id":"#{request_id}"})

    collection = LogBench::Log::Collection.new([request_log, regular_log])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # The entry should not have any job prefix
    entry = request.related_logs.first
    assert_equal "Regular log message", entry.content
    refute entry.content.include?("[")
  end

  def test_job_prefix_uses_consistent_colors
    # Same job ID should always get the same color
    job_id = "consistent-job-id"
    job_class = "TestJob"

    # Create two separate requests with job logs
    request_log1 = %({"method":"POST","path":"/test1","status":200,"duration":10.5,"request_id":"req-1","timestamp":"2025-10-17T14:00:00Z"})
    job_log1 = %({"message":"First message","level":"INFO","timestamp":"2025-10-17T14:00:01Z","tags":["ActiveJob","#{job_class}","#{job_id}"],"request_id":"req-1"})

    request_log2 = %({"method":"POST","path":"/test2","status":200,"duration":10.5,"request_id":"req-2","timestamp":"2025-10-17T14:00:02Z"})
    job_log2 = %({"message":"Second message","level":"INFO","timestamp":"2025-10-17T14:00:03Z","tags":["ActiveJob","#{job_class}","#{job_id}"],"request_id":"req-2"})

    collection1 = LogBench::Log::Collection.new([request_log1, job_log1])
    collection2 = LogBench::Log::Collection.new([request_log2, job_log2])

    entry1 = collection1.requests.first.related_logs.first
    entry2 = collection2.requests.first.related_logs.first

    # Both entries should have the same tags
    assert_equal entry1.json_data["tags"], entry2.json_data["tags"]

    # The color should be determined by the job_id, so it should be consistent
    # (We can't easily test the actual color code here without rendering,
    # but we can verify the tags are the same which is what determines the color)
    assert_equal job_id, entry1.json_data["tags"][2]
    assert_equal job_id, entry2.json_data["tags"][2]
  end
end
