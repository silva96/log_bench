# frozen_string_literal: true

require "test_helper"

class TestJobExecutionTracking < Minitest::Test
  # LogStruct job execution event tests
  def test_logstruct_job_start_detection
    # LogStruct uses evt:"start" with src:"job"
    data = {"src" => "job", "evt" => "start", "job_id" => "abc-123", "job_class" => "TestJob"}
    assert LogBench::Log::Parser.job_start_message?(data)

    # Should not detect other events as start
    enqueue_data = {"src" => "job", "evt" => "enqueue", "job_id" => "abc-123"}
    refute LogBench::Log::Parser.job_start_message?(enqueue_data)

    finish_data = {"src" => "job", "evt" => "finish", "job_id" => "abc-123"}
    refute LogBench::Log::Parser.job_start_message?(finish_data)
  end

  def test_logstruct_job_finish_detection
    # LogStruct uses evt:"finish" with src:"job"
    data = {"src" => "job", "evt" => "finish", "job_id" => "abc-123", "job_class" => "TestJob", "duration_ms" => 123.45}
    assert LogBench::Log::Parser.job_finish_message?(data)

    # Should not detect other events as finish
    enqueue_data = {"src" => "job", "evt" => "enqueue", "job_id" => "abc-123"}
    refute LogBench::Log::Parser.job_finish_message?(enqueue_data)

    start_data = {"src" => "job", "evt" => "start", "job_id" => "abc-123"}
    refute LogBench::Log::Parser.job_finish_message?(start_data)
  end

  def test_logstruct_job_start_entry_parsing
    logstruct_log = '{"src":"job","evt":"start","job_id":"79729d72-f0df-468e-a6da-9064ec9e845e","job_class":"TestJob","queue_name":"default","attempt":1,"req_id":"8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9","ts":"2026-01-23T19:36:20.129+13:00"}'

    entry = LogBench::Log::Parser.parse_line(logstruct_log)

    assert_instance_of LogBench::Log::JobStartEntry, entry
    assert_equal "79729d72-f0df-468e-a6da-9064ec9e845e", entry.job_id
    assert_equal "TestJob", entry.job_class
    assert_equal 1, entry.attempt
    assert_equal "8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9", entry.request_id
  end

  def test_logstruct_job_start_entry_content
    logstruct_log = '{"src":"job","evt":"start","job_id":"79729d72-f0df-468e-a6da-9064ec9e845e","job_class":"TestJob","queue_name":"default","attempt":1,"req_id":"8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9","ts":"2026-01-23T19:36:20.129+13:00"}'

    entry = LogBench::Log::Parser.parse_line(logstruct_log)

    assert_match(/Started TestJob/, entry.content)
    assert_match(/Job ID: 79729d72-f0df-468e-a6da-9064ec9e845e/, entry.content)
  end

  def test_logstruct_job_start_entry_with_retry_attempt
    logstruct_log = '{"src":"job","evt":"start","job_id":"79729d72-f0df-468e-a6da-9064ec9e845e","job_class":"TestJob","queue_name":"default","attempt":3,"req_id":"8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9","ts":"2026-01-23T19:36:20.129+13:00"}'

    entry = LogBench::Log::Parser.parse_line(logstruct_log)

    assert_instance_of LogBench::Log::JobStartEntry, entry
    assert_equal 3, entry.attempt
    assert_match(/attempt 3/, entry.content)
  end

  def test_logstruct_job_finish_entry_parsing
    logstruct_log = '{"src":"job","evt":"finish","job_id":"79729d72-f0df-468e-a6da-9064ec9e845e","job_class":"TestJob","queue_name":"default","duration_ms":123.45,"req_id":"8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9","ts":"2026-01-23T19:36:20.129+13:00"}'

    entry = LogBench::Log::Parser.parse_line(logstruct_log)

    assert_instance_of LogBench::Log::JobFinishEntry, entry
    assert_equal "79729d72-f0df-468e-a6da-9064ec9e845e", entry.job_id
    assert_equal "TestJob", entry.job_class
    assert_equal 123.45, entry.duration_ms
    assert_equal "8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9", entry.request_id
  end

  def test_logstruct_job_finish_entry_content
    logstruct_log = '{"src":"job","evt":"finish","job_id":"79729d72-f0df-468e-a6da-9064ec9e845e","job_class":"TestJob","queue_name":"default","duration_ms":123.45,"req_id":"8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9","ts":"2026-01-23T19:36:20.129+13:00"}'

    entry = LogBench::Log::Parser.parse_line(logstruct_log)

    assert_match(/Finished TestJob/, entry.content)
    assert_match(/Job ID: 79729d72-f0df-468e-a6da-9064ec9e845e/, entry.content)
    assert_match(/123\.45ms/, entry.content)
  end

  def test_logstruct_full_job_lifecycle_with_request
    request_id = "8cc2f6c7-6fd9-4d41-8626-847a6f1c5bb9"
    job_id = "79729d72-f0df-468e-a6da-9064ec9e845e"

    # HTTP request
    request_log = %({"src":"rails","evt":"request","method":"GET","path":"/","status":200,"duration_ms":62.57,"controller":"HomeController","action":"index","req_id":"#{request_id}","ts":"2026-01-23T19:36:20.157+13:00"})

    # Job scheduled (enqueued)
    schedule_log = %({"src":"job","evt":"schedule","job_id":"#{job_id}","job_class":"TestJob","queue_name":"default","req_id":"#{request_id}","ts":"2026-01-23T19:36:20.129+13:00"})

    # Job started
    start_log = %({"src":"job","evt":"start","job_id":"#{job_id}","job_class":"TestJob","queue_name":"default","attempt":1,"req_id":"#{request_id}","ts":"2026-01-23T19:36:22.000+13:00"})

    # Job finished
    finish_log = %({"src":"job","evt":"finish","job_id":"#{job_id}","job_class":"TestJob","queue_name":"default","duration_ms":1500.25,"req_id":"#{request_id}","ts":"2026-01-23T19:36:23.500+13:00"})

    # Parse all logs
    state = test_state
    collection = LogBench::Log::Collection.new([request_log, schedule_log, start_log, finish_log])
    requests = collection.requests

    # Should have one request
    assert_equal 1, requests.size
    request = requests.first
    assert_equal request_id, request.request_id

    # Should have 3 related logs: schedule, start, finish
    assert_equal 3, request.related_logs.size

    # Verify each entry type
    enqueue_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobEnqueueEntry) }
    start_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobStartEntry) }
    finish_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobFinishEntry) }

    assert_equal 1, enqueue_entries.size, "Should have 1 enqueue entry"
    assert_equal 1, start_entries.size, "Should have 1 start entry"
    assert_equal 1, finish_entries.size, "Should have 1 finish entry"

    # All should have the same job_id
    assert_equal job_id, enqueue_entries.first.job_id
    assert_equal job_id, start_entries.first.job_id
    assert_equal job_id, finish_entries.first.job_id

    # All should have the same request_id
    assert_equal request_id, enqueue_entries.first.request_id
    assert_equal request_id, start_entries.first.request_id
    assert_equal request_id, finish_entries.first.request_id
  end

  def test_job_execution_linked_via_job_id_mapping
    # This tests the scenario where job execution logs don't have request_id
    # but can be linked via the job_id → request_id mapping
    request_id = "req-abc-123"
    job_id = "job-xyz-789"

    # HTTP request
    request_log = %({"method":"POST","path":"/users","status":200,"request_id":"#{request_id}","timestamp":"2025-01-01T10:00:00Z"})

    # Job enqueued (has request_id)
    enqueue_log = %({"src":"job","evt":"schedule","job_id":"#{job_id}","job_class":"TestJob","req_id":"#{request_id}","ts":"2025-01-01T10:00:01Z"})

    # Job started (NO request_id - simulating async execution)
    start_log = %({"src":"job","evt":"start","job_id":"#{job_id}","job_class":"TestJob","attempt":1,"ts":"2025-01-01T10:00:05Z"})

    # Job finished (NO request_id - simulating async execution)
    finish_log = %({"src":"job","evt":"finish","job_id":"#{job_id}","job_class":"TestJob","duration_ms":500.0,"ts":"2025-01-01T10:00:05Z"})

    # Parse all logs
    state = test_state
    collection = LogBench::Log::Collection.new([request_log, enqueue_log, start_log, finish_log])
    requests = collection.requests

    # Should have one request with all logs grouped
    assert_equal 1, requests.size
    request = requests.first
    assert_equal request_id, request.request_id

    # Should have 3 related logs: enqueue, start, finish
    assert_equal 3, request.related_logs.size

    # The start and finish entries should have been enriched with request_id
    start_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobStartEntry) }
    finish_entries = request.related_logs.select { |log| log.is_a?(LogBench::Log::JobFinishEntry) }

    assert_equal 1, start_entries.size
    assert_equal 1, finish_entries.size

    # They should have request_id from the mapping
    assert_equal request_id, start_entries.first.request_id, "Start entry should have request_id from job mapping"
    assert_equal request_id, finish_entries.first.request_id, "Finish entry should have request_id from job mapping"
  end

  private

  def test_state
    # Reset and return fresh State for testing
    LogBench::App::State.instance.instance_variable_set(:@job_ids_map, {})
    LogBench::App::State.instance
  end
end
