# lib/export_ms_todo/exporters/task_chunker.rb
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class TaskChunker
      def initialize(list, tasks, exporter, max_size = 300)
        @list = list
        @tasks = tasks
        @exporter = exporter
        @max_size = max_size
      end

      def export
        chunks = split_tasks_into_chunks

        chunks.map.with_index do |chunk, index|
          {
            filename: Utils.sanitize_filename(@list['displayName'], 'csv').sub('.csv', "-#{index + 1}.csv"),
            content: @exporter.generate_csv(@list, chunk),
            part: index + 1,
            total_parts: chunks.size
          }
        end
      end

      private

      def split_tasks_into_chunks
        chunks = []
        current_chunk = []
        current_count = 0

        @tasks.each do |task|
          task_size = task.total_task_count

          # Edge case: single task exceeds limit
          if task_size > @max_size
            warn "⚠️  Task '#{task.title}' has #{task.subtask_count} subtasks (exceeds #{@max_size} limit)"

            # Flush current chunk if not empty
            chunks << current_chunk if current_chunk.any?

            # Put oversized task in its own chunk
            chunks << [task]

            # Reset for next chunk
            current_chunk = []
            current_count = 0
            next
          end

          # Start new chunk if adding this task would exceed limit
          if current_count + task_size > @max_size && current_chunk.any?
            chunks << current_chunk
            current_chunk = []
            current_count = 0
          end

          current_chunk << task
          current_count += task_size
        end

        # Don't forget the last chunk
        chunks << current_chunk if current_chunk.any?

        chunks
      end
    end
  end
end
