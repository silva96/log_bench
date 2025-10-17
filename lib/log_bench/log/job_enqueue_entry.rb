# frozen_string_literal: true

module LogBench
  module Log
    class JobEnqueueEntry < Entry
      attr_reader :job_id

      def initialize(json_data)
        super
        self.type = :job_enqueue
        self.job_id = extract_job_id
      end

      private

      attr_writer :job_id

      def extract_job_id
        Parser.extract_job_id_from_enqueue(content)
      end
    end
  end
end
