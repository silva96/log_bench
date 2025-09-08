# frozen_string_literal: true

module LogBench
  module App
    class CopyHandler
      def initialize(state, renderer)
        self.state = state
        self.renderer = renderer
      end

      def copy_to_clipboard
        if state.left_pane_focused?
          copy_selected_request
        else
          copy_selected_detail_entry
        end
      end

      def find_companion_call_line(request, selected_entry_id)
        # Get the detail lines for the current request
        lines = renderer&.get_cached_detail_lines(request)
        return nil unless lines

        # Find all lines belonging to the selected entry
        selected_lines = lines.select { |line| line[:entry_id] == selected_entry_id }

        # Look for a call line (starts with "↳") in the same entry group
        call_line = selected_lines.find do |line|
          text = line[:text]&.gsub(/\e\[[0-9;]*m/, "")&.strip
          text&.start_with?("↳")
        end

        if call_line
          # Clean and return the call line content
          call_line[:text].gsub(/\e\[[0-9;]*m/, "").strip
        end
      end

      private

      attr_accessor :state, :renderer

      def copy_selected_request
        request = state.current_request
        return unless request

        # Create a comprehensive text representation of the request
        content = []
        content << "```"
        content << "#{request.method} #{request.path} #{request.status}"
        content << "Duration: #{request.duration}ms" if request.duration
        content << "Controller: #{request.controller}" if request.controller
        content << "Action: #{request.action}" if request.action
        content << "Request ID: #{request.request_id}" if request.request_id
        content << "Timestamp: #{request.timestamp}" if request.timestamp
        content << "Params: #{request.params}" if request.params && !request.params.empty?

        # Add query summary if there are related logs
        if request.related_logs && !request.related_logs.empty?
          query_summary = QuerySummary.new(request).build_text_summary
          content << ""
          content << query_summary
        end

        content << "```"

        Clipboard.copy(content.join("\n"))
      end

      def copy_selected_detail_entry
        request = state.current_request
        return unless request

        # Get the detail lines for the current request to find entry IDs
        lines = renderer&.get_cached_detail_lines(request)
        return unless lines

        # Find all unique entry IDs, excluding separator lines
        entry_ids = lines.reject { |line| line[:separator] }.map { |line| line[:entry_id] }.compact.uniq
        return if state.detail_selected_entry >= entry_ids.size

        # Get the selected entry ID
        selected_entry_id = entry_ids[state.detail_selected_entry]
        return unless selected_entry_id

        # Find lines belonging to the selected entry and look for original_entry reference
        selected_lines = lines.select { |line| line[:entry_id] == selected_entry_id }

        # Look for a line that has the original_entry reference
        original_entry = nil
        selected_lines.each do |line|
          if line[:original_entry]
            original_entry = line[:original_entry]
            break
          end
        end

        if original_entry
          # Use the original log entry content
          content = original_entry.content
          return unless content

          # Remove ANSI escape codes for clean copying
          clean_content = content.gsub(/\e\[[0-9;]*m/, "").strip

          # Check if this is a SQL query and if there's a companion call line
          is_sql_query = sql_query?(clean_content)

          if is_sql_query
            # Look for companion call line in the same entry group
            call_line_content = find_companion_call_line(request, selected_entry_id)

            if call_line_content
              # Include both SQL query and call line
              full_content = "#{clean_content}\n#{call_line_content}"
              Clipboard.copy("```sql\n#{full_content}\n```")
            else
              # Just the SQL query
              Clipboard.copy("```sql\n#{clean_content}\n```")
            end
          else
            Clipboard.copy(clean_content)
          end
        else
          # Fallback to the old method - join wrapped lines but try to reconstruct original
          content = selected_lines.map do |line|
            text = line[:text] || ""
            # Remove ANSI escape codes and trim padding
            text.gsub(/\e\[[0-9;]*m/, "").strip
          end.reject(&:empty?)

          # Try to join the content intelligently
          content_text = content.join(" ").gsub(/\s+/, " ").strip

          # Check if this is a SQL query
          is_sql_query = sql_query?(content_text)

          if is_sql_query
            Clipboard.copy("```sql\n#{content_text}\n```")
          else
            Clipboard.copy(content_text)
          end
        end
      end

      def sql_query?(text)
        # Check for common SQL keywords that indicate this is a SQL query
        sql_keywords = %w[SELECT INSERT UPDATE DELETE TRANSACTION BEGIN COMMIT ROLLBACK SAVEPOINT]
        pattern = /\b(#{sql_keywords.join("|")})\b/i
        text.match?(pattern)
      end
    end
  end
end
