# frozen_string_literal: true

module LogBench
  # Sidekiq middleware to capture job information for logging
  class SidekiqMiddleware
    def call(worker, job, queue)
      # Set job information in Current attributes
      if defined?(LogBench::Current)
        LogBench::Current.job_id = job['jid']
        LogBench::Current.job_class = job['class']
      end

      yield
    ensure
      # Clear job information after job completes
      if defined?(LogBench::Current)
        LogBench::Current.job_id = nil
        LogBench::Current.job_class = nil
      end
    end
  end
end

