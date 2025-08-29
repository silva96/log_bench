# frozen_string_literal: true

module LogBench
  module App
    class QuerySummary
      def initialize(request)
        self.request = request
      end

      def build_stats
        # Use memoized methods from request object for better performance
        stats = {
          total_queries: request.query_count,
          total_time: request.total_query_time,
          cached_queries: request.cached_query_count,
          select: 0,
          insert: 0,
          update: 0,
          delete: 0,
          transaction: 0
        }

        # Categorize by operation type for breakdown
        request.related_logs.each do |log|
          next unless [:sql, :cache].include?(log.type)

          categorize_sql_operation(log, stats)
        end

        stats
      end

      def build_text_summary
        query_stats = build_stats

        summary_lines = []
        summary_lines << "Query Summary:"

        if query_stats[:total_queries] > 0
          summary_lines << build_summary_line(query_stats)

          breakdown_line = build_breakdown_line(query_stats)
          summary_lines << breakdown_line unless breakdown_line.empty?
        end

        summary_lines.join("\n")
      end

      def build_summary_line(query_stats = nil)
        query_stats ||= build_stats

        summary_parts = ["#{query_stats[:total_queries]} queries"]

        if query_stats[:total_time] > 0
          time_part = "#{query_stats[:total_time].round(1)}ms total"
          time_part += ", #{query_stats[:cached_queries]} cached" if query_stats[:cached_queries] > 0
          summary_parts << "(#{time_part})"
        elsif query_stats[:cached_queries] > 0
          summary_parts << "(#{query_stats[:cached_queries]} cached)"
        end

        summary_parts.join(" ")
      end

      def build_breakdown_line(query_stats = nil)
        query_stats ||= build_stats

        breakdown_parts = [
          ("#{query_stats[:select]} SELECT" if query_stats[:select] > 0),
          ("#{query_stats[:insert]} INSERT" if query_stats[:insert] > 0),
          ("#{query_stats[:update]} UPDATE" if query_stats[:update] > 0),
          ("#{query_stats[:delete]} DELETE" if query_stats[:delete] > 0),
          ("#{query_stats[:transaction]} TRANSACTION" if query_stats[:transaction] > 0)
        ].compact

        breakdown_parts.join(", ")
      end

      private

      attr_accessor :request

      def categorize_sql_operation(log, stats)
        # Use unified QueryEntry for both SQL and CACHE entries
        return unless log.is_a?(LogBench::Log::QueryEntry)

        if log.select?
          stats[:select] += 1
        elsif log.insert?
          stats[:insert] += 1
        elsif log.update?
          stats[:update] += 1
        elsif log.delete?
          stats[:delete] += 1
        elsif log.transaction? || log.begin? || log.commit? || log.rollback? || log.savepoint?
          stats[:transaction] += 1
        end
      end
    end
  end
end
