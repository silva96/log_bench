# frozen_string_literal: true

module LogBench
  module Log
    class JobFinishEntry < Entry
      attr_reader :job_id, :job_class, :duration_ms

      def initialize(json_data)
        super
        self.type = :job_finish
        @job_id = extract_job_id
        @job_class = json_data["job_class"]
        @duration_ms = json_data["duration_ms"]
        build_content_for_logstruct if logstruct_format?
      end

      private

      def extract_job_id
        json_data["job_id"]
      end

      def logstruct_format?
        json_data["evt"] == "finish" && json_data["src"] == "job"
      end

      def build_content_for_logstruct
        job_class = @job_class || "Job"
        queue = json_data["queue_name"]
        duration = @duration_ms ? " in #{@duration_ms.round(2)}ms" : ""

        parts = ["Finished #{job_class} (Job ID: #{@job_id})#{duration}"]
        parts << "from #{queue}" if queue

        @content = parts.join(" ")
      end
    end
  end
end
