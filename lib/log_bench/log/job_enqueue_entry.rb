# frozen_string_literal: true

module LogBench
  module Log
    class JobEnqueueEntry < Entry
      attr_reader :job_id

      def initialize(json_data)
        super
        self.type = :job_enqueue
        self.job_id = extract_job_id
        build_content_for_logstruct if logstruct_format?
      end

      private

      attr_writer :job_id

      def extract_job_id
        # LogStruct has job_id as a direct field
        json_data["job_id"] || Parser.extract_job_id_from_enqueue(content)
      end

      def logstruct_format?
        json_data["evt"] == "schedule" && json_data["src"] == "job"
      end

      def build_content_for_logstruct
        job_class = json_data["job_class"] || "Job"
        queue = json_data["queue_name"]
        scheduled_at = json_data["scheduled_at"]

        parts = ["Enqueued #{job_class} (Job ID: #{job_id})"]
        parts << "to #{queue}" if queue
        parts << "at #{scheduled_at}" if scheduled_at

        @content = parts.join(" ")
      end
    end
  end
end
