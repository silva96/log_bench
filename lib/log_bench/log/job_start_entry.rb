# frozen_string_literal: true

module LogBench
  module Log
    class JobStartEntry < Entry
      attr_reader :job_id, :job_class, :attempt

      def initialize(json_data)
        super
        self.type = :job_start
        @job_id = extract_job_id
        @job_class = json_data["job_class"]
        @attempt = json_data["attempt"]
        build_content_for_logstruct if logstruct_format?
      end

      private

      def extract_job_id
        json_data["job_id"]
      end

      def logstruct_format?
        json_data["evt"] == "start" && json_data["src"] == "job"
      end

      def build_content_for_logstruct
        job_class = @job_class || "Job"
        queue = json_data["queue_name"]
        attempt_info = @attempt && @attempt > 1 ? " (attempt #{@attempt})" : ""

        parts = ["Started #{job_class} (Job ID: #{@job_id})#{attempt_info}"]
        parts << "from #{queue}" if queue

        @content = parts.join(" ")
      end
    end
  end
end
