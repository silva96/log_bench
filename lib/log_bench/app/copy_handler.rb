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

        # Get the detail lines for the current request
        lines = renderer&.get_cached_detail_lines(request)
        return unless lines

        # Find all unique entry IDs, excluding separator lines
        entry_ids = lines.reject { |line| line[:separator] }.map { |line| line[:entry_id] }.compact.uniq
        return if state.detail_selected_entry >= entry_ids.size

        # Get the selected entry ID
        selected_entry_id = entry_ids[state.detail_selected_entry]
        return unless selected_entry_id

        # Find all lines belonging to the selected entry
        selected_lines = lines.select { |line| line[:entry_id] == selected_entry_id }

        # Extract the text content, removing ANSI codes and padding
        content = selected_lines.map do |line|
          text = line[:text] || ""
          # Remove ANSI escape codes and trim padding
          text.gsub(/\e\[[0-9;]*m/, "").strip
        end.reject(&:empty?)

        # Check if this is a SQL query by looking for SQL keywords in the content
        content_text = content.join(" ")
        is_sql_query = sql_query?(content_text)

        if is_sql_query
          Clipboard.copy("```sql\n#{content.join("\n")}\n```")
        else
          Clipboard.copy(content.join("\n"))
        end
      end

      def sql_query?(text)
        # Check for common SQL keywords that indicate this is a SQL query
        sql_keywords = %w[SELECT INSERT UPDATE DELETE TRANSACTION BEGIN COMMIT ROLLBACK SAVEPOINT]
        sql_keywords.any? { |keyword| text.upcase.include?(keyword) }
      end
    end
  end
end
