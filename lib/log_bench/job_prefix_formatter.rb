# frozen_string_literal: true

module LogBench
  # Shared module for formatting job prefixes with ANSI colors
  # Used by both JsonFormatter (when writing logs) and Parser (when reading old logs)
  module JobPrefixFormatter
    # Job color palette - using standard colors only (no bright colors)
    JOB_COLORS = [
      31, # Red
      32, # Green
      33, # Yellow
      34, # Blue
      35, # Magenta
      36  # Cyan
    ].freeze

    # Extract job info from ActiveJob tags
    # Returns [job_id, job_class] or nil if not a valid ActiveJob tag
    def extract_job_info_from_tags(tags)
      return nil unless tags.is_a?(Array) && tags.size >= 3
      return nil unless tags[0] == "ActiveJob"

      # ActiveJob tags format: ["ActiveJob", "JobClassName", "job-id"]
      job_class = tags[1]
      job_id = tags[2]
      return nil unless job_class && job_id

      [job_id, job_class]
    end

    # Build colored job prefix using ANSI color codes
    def build_colored_job_prefix(job_class, job_id)
      # Pick a color based on the job ID for visual differentiation
      color_code = pick_job_color(job_id)
      "\u001b[1m\u001b[#{color_code}m[#{job_class}##{job_id}]\u001b[0m"
    end

    # Pick a consistent color for a job based on its ID
    def pick_job_color(job_id)
      # Use a simple hash of the job ID to pick a consistent color
      # This ensures the same job ID always gets the same color
      hash = job_id.to_s.bytes.sum
      JOB_COLORS[hash % JOB_COLORS.length]
    end
  end
end
