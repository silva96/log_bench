# frozen_string_literal: true

module LogBench
  # Sidekiq middleware to capture job ID (jid) and job class name and set them in Current attributes
  # for inclusion in JSON logs
  class SidekiqMiddleware
    def call(worker, job, _queue)
      if defined?(LogBench::Current)
        # Only set Current attributes for direct Sidekiq jobs
        # ActiveJob jobs will use tags instead
        unless activejob_wrapper?(job["class"])
          LogBench::Current.jid = job["jid"]
          LogBench::Current.job_class = job["class"] || worker.class.name
        end
      end

      yield
    ensure
      if defined?(LogBench::Current)
        # Clean up the job attributes after the job completes
        LogBench::Current.jid = nil
        LogBench::Current.job_class = nil
      end
    end

    private

    def activejob_wrapper?(job_class)
      job_class == "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"
    end
  end
end
