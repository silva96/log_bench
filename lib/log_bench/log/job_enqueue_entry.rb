# frozen_string_literal: true

module LogBench
  module Log
    class JobEnqueueEntry < Entry
      attr_reader :job_class, :job_id

      def initialize(json_data)
        super(json_data)
        self.type = :job_enqueue
        self.job_class = extract_job_class(json_data)
        self.job_id = json_data["job_id"]
      end

      private

      attr_writer :job_class, :job_id

      def extract_job_class(data)
        # Try to extract job class from the message
        message = data["message"] || ""
        if message.include?("was enqueued")
          # Extract class name from "SomeJob was enqueued" pattern
          match = message.match(/^([A-Z][A-Za-z0-9:]*)\s+was enqueued/)
          return match[1] if match
        end
        
        # Fallback to job_class field if present
        data["job_class"]
      end
    end
  end
end

