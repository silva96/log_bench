# frozen_string_literal: true

require "test_helper"

class TestJobEnqueueTracking < Minitest::Test
  def test_parse_job_enqueue_message
    # Use matching request_id for both the request and the enqueue log
    request_log = '{"method":"GET","path":"/users","status":200,"duration":45.2,"controller":"UsersController","action":"index","request_id":"d72f06fa-71f1-4fb4-a27f-d9b36fe17593","timestamp":"2025-01-01T10:00:00Z"}'
    enqueue_log = '{"message":"Enqueued TestJob (Job ID: 8afaa702-7b0d-4d20-91ad-65bbf78ee0c8) to Async(default) at 2025-10-17 14:02:51 UTC","level":"INFO","timestamp":"2025-10-17T14:02:49.976Z","time":1760709769.9763,"request_id":"d72f06fa-71f1-4fb4-a27f-d9b36fe17593","tags":["ActiveJob"]}'

    collection = LogBench::Log::Collection.new([request_log, enqueue_log])
    requests = collection.requests

    assert_equal 1, requests.size
    request = requests.first

    # Should have one job enqueue entry in related logs
    job_enqueue_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobEnqueueEntry) }
    assert_equal 1, job_enqueue_entries.size

    job_enqueue = job_enqueue_entries.first
    assert_equal "8afaa702-7b0d-4d20-91ad-65bbf78ee0c8", job_enqueue.job_id
    assert_equal "d72f06fa-71f1-4fb4-a27f-d9b36fe17593", job_enqueue.request_id
  end

  def test_state_registers_job_enqueue
    state = test_state

    # Register a job enqueue
    job_id = "8afaa702-7b0d-4d20-91ad-65bbf78ee0c8"
    request_id = "d72f06fa-71f1-4fb4-a27f-d9b36fe17593"

    state.register_job_enqueue(job_id, request_id)

    # Should be able to look up the request_id by job_id
    assert_equal request_id, state.request_id_for_job(job_id)
  end

  def test_monitor_registers_job_enqueues
    state = test_state

    # Create a request with a job enqueue entry (matching request_id)
    request_log = '{"method":"GET","path":"/users","status":200,"duration":45.2,"controller":"UsersController","action":"index","request_id":"d72f06fa-71f1-4fb4-a27f-d9b36fe17593","timestamp":"2025-01-01T10:00:00Z"}'
    enqueue_log = '{"message":"Enqueued TestJob (Job ID: 8afaa702-7b0d-4d20-91ad-65bbf78ee0c8) to Async(default) at 2025-10-17 14:02:51 UTC","level":"INFO","timestamp":"2025-10-17T14:02:49.976Z","time":1760709769.9763,"request_id":"d72f06fa-71f1-4fb4-a27f-d9b36fe17593","tags":["ActiveJob"]}'
    collection = LogBench::Log::Collection.new([request_log, enqueue_log])
    new_requests = collection.requests

    # Simulate what Monitor does
    new_requests.each do |request|
      request.related_logs.each do |log|
        next unless log.is_a?(LogBench::Log::JobEnqueueEntry)

        state.register_job_enqueue(log.job_id, request.request_id)
      end
    end

    # Should have registered the job enqueue
    assert_equal "d72f06fa-71f1-4fb4-a27f-d9b36fe17593", state.request_id_for_job("8afaa702-7b0d-4d20-91ad-65bbf78ee0c8")
  end

  def test_extract_job_id_from_various_formats
    # Test with standard format
    message1 = "Enqueued TestJob (Job ID: 8afaa702-7b0d-4d20-91ad-65bbf78ee0c8) to Async(default)"
    job_id1 = LogBench::Log::Parser.extract_job_id_from_enqueue(message1)
    assert_equal "8afaa702-7b0d-4d20-91ad-65bbf78ee0c8", job_id1

    # Test with different job name
    message2 = "Enqueued EmailDeliveryJob (Job ID: abc-123-def-456) to Sidekiq(mailers)"
    job_id2 = LogBench::Log::Parser.extract_job_id_from_enqueue(message2)
    assert_equal "abc-123-def-456", job_id2
  end

  def test_job_enqueue_message_detection
    # Should detect job enqueue messages
    data1 = {"message" => "Enqueued TestJob (Job ID: 123-456) to Async(default)"}
    assert LogBench::Log::Parser.job_enqueue_message?(data1)

    # Should not detect regular messages
    data2 = {"message" => "Regular log message"}
    refute LogBench::Log::Parser.job_enqueue_message?(data2)

    # Should not detect SQL queries
    data3 = {"message" => "SELECT * FROM users"}
    refute LogBench::Log::Parser.job_enqueue_message?(data3)
  end

  def test_full_workflow_example
    # This test demonstrates the complete workflow:
    # 1. HTTP request comes in
    # 2. Request enqueues a job
    # 3. Job ID is mapped to request ID
    # 4. Later, we can look up which request enqueued which job

    state = test_state

    # Step 1: HTTP request arrives and enqueues a job
    request_id = "req-abc-123"
    job_id = "job-xyz-789"

    request_log = %({"method":"POST","path":"/users","status":200,"duration":45.2,"controller":"UsersController","action":"create","request_id":"#{request_id}","timestamp":"2025-01-01T10:00:00Z"})
    enqueue_log = %({"message":"Enqueued EmailJob (Job ID: #{job_id}) to Async(mailers)","level":"INFO","timestamp":"2025-01-01T10:00:01Z","request_id":"#{request_id}","tags":["ActiveJob"]})

    # Step 2: Parse the logs
    collection = LogBench::Log::Collection.new([request_log, enqueue_log])
    requests = collection.requests

    # Step 3: Register the job enqueue (this happens automatically in Monitor)
    requests.each do |request|
      request.related_logs.each do |log|
        next unless log.is_a?(LogBench::Log::JobEnqueueEntry)

        state.register_job_enqueue(log.job_id, request.request_id)
      end
    end

    # Step 4: Later, when we see job logs with only job_id, we can look up the request_id
    found_request_id = state.request_id_for_job(job_id)
    assert_equal request_id, found_request_id

    # This allows us to:
    # - Find which HTTP request triggered this job
    # - Group job execution logs with the originating request
    # - Trace the full lifecycle: HTTP request → job enqueue → job execution
  end

  def test_job_log_gets_request_id_from_mapping
    # This is the key test: job logs without request_id get enriched with it
    request_id = "d72f06fa-71f1-4fb4-a27f-d9b36fe17593"
    job_id = "8afaa702-7b0d-4d20-91ad-65bbf78ee0c8"

    # First, build the mapping in State
    state = test_state
    state.register_job_enqueue(job_id, request_id)

    # Now parse a job log that has NO request_id, only tags with job_id
    job_log = %({"message":"[TestJob##{job_id}] TestJob#perform at 2025-10-17 11:02:51 -0300","level":"INFO","timestamp":"2025-10-17T14:02:51.993Z","time":1760709771.993279,"tags":["ActiveJob","TestJob","#{job_id}"]})

    # Parse (will use State singleton to enrich)
    collection = LogBench::Log::Collection.new([job_log])

    # Should create an orphan request with the mapped request_id
    assert_equal 1, collection.orphan_requests.size
    request = collection.orphan_requests.first

    # The request should have the request_id from the mapping!
    assert_equal request_id, request.request_id

    # And the job log should be in the related_logs
    assert_equal 1, request.related_logs.size
    assert_equal request_id, request.related_logs.first.request_id
  end

  def test_job_log_without_mapping_gets_discarded
    # Job log without a mapping should be discarded (no request_id means it can't be grouped)
    job_id = "unknown-job-id"

    job_log = %({"message":"[TestJob##{job_id}] Processing...","level":"INFO","timestamp":"2025-10-17T14:02:51.993Z","tags":["ActiveJob","TestJob","#{job_id}"]})

    # Parse WITHOUT job_ids_map
    collection = LogBench::Log::Collection.new([job_log])

    # Should be empty since there's no request_id and no mapping
    assert_equal 0, collection.requests.size
  end

  def test_initial_load_with_job_logs
    # This simulates the initial load scenario where we have:
    # 1. A request that enqueues a job
    # 2. Job execution logs that come later
    # All in the same log file

    request_id = "req-initial-123"
    job_id = "job-initial-456"

    # Simulate a log file with request, enqueue, and job execution logs
    request_log = %({"method":"POST","path":"/users","status":200,"duration":45.2,"controller":"UsersController","action":"create","request_id":"#{request_id}","timestamp":"2025-01-01T10:00:00Z"})
    enqueue_log = %({"message":"Enqueued EmailJob (Job ID: #{job_id}) to Async(mailers)","level":"INFO","timestamp":"2025-01-01T10:00:01Z","request_id":"#{request_id}","tags":["ActiveJob"]})
    job_log_1 = %({"message":"[EmailJob##{job_id}] Performing EmailJob","level":"INFO","timestamp":"2025-01-01T10:00:05Z","tags":["ActiveJob","EmailJob","#{job_id}"]})
    job_log_2 = %({"message":"[EmailJob##{job_id}] Sending email","level":"INFO","timestamp":"2025-01-01T10:00:06Z","tags":["ActiveJob","EmailJob","#{job_id}"]})
    job_log_3 = %({"message":"[EmailJob##{job_id}] Performed EmailJob","level":"INFO","timestamp":"2025-01-01T10:00:07Z","tags":["ActiveJob","EmailJob","#{job_id}"]})

    all_logs = [request_log, enqueue_log, job_log_1, job_log_2, job_log_3]

    # Single pass: Parse and enrich (State singleton handles the mapping)
    state = test_state
    collection = LogBench::Log::Collection.new(all_logs)

    # Verify the mapping was built in State
    assert_equal request_id, state.request_id_for_job(job_id)

    # Now we should have the request with ALL logs grouped together
    requests = collection.requests
    assert_equal 1, requests.size

    request = requests.first
    assert_equal request_id, request.request_id

    # Should have: enqueue + 3 job logs = 4 related logs
    assert_equal 4, request.related_logs.size

    # All job logs should have the request_id
    job_logs = request.related_logs.select { |log| log.content.include?("EmailJob#") }
    assert_equal 3, job_logs.size
    job_logs.each do |log|
      assert_equal request_id, log.request_id, "Job log should have request_id from mapping"
    end
  end
end
