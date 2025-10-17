# frozen_string_literal: true

if defined?(ActiveSupport::CurrentAttributes)
  module LogBench
    class Current < ActiveSupport::CurrentAttributes
      attribute :request_id, :jid, :job_class
    end
  end
end
