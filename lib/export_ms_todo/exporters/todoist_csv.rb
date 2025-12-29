# lib/export_ms_todo/exporters/todoist_csv.rb
require 'csv'
# require_relative 'task_chunker'
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class TodoistCSV
      MAX_TASKS_PER_FILE = 300

      TODOIST_HEADERS = [
        'TYPE', 'CONTENT', 'DESCRIPTION', 'PRIORITY', 'INDENT',
        'AUTHOR', 'RESPONSIBLE', 'DATE', 'DATE_LANG', 'TIMEZONE'
      ].freeze

      def export(grouped_tasks)
        grouped_tasks.flat_map do |group|
          list = group[:list]
          tasks = group[:tasks]

          # KISS: Simple path for most lists (≤300 tasks)
          if total_task_count(tasks) <= MAX_TASKS_PER_FILE
            single_file_export(list, tasks)
          else
            # Complex path: delegate to specialist
            # TaskChunker.new(list, tasks, self).export
            # For now, just use single_file_export (will be replaced with TaskChunker in Task 7)
            single_file_export(list, tasks)
          end
        end
      end

      def generate_csv(list, tasks)
        CSV.generate(headers: true, write_headers: true) do |csv|
          csv << TODOIST_HEADERS

          tasks.each do |task|
            add_task_rows(csv, task)
          end
        end
      end

      private

      def single_file_export(list, tasks)
        [{
          filename: Utils.sanitize_filename(list['displayName'], 'csv'),
          content: generate_csv(list, tasks)
        }]
      end

      def sanitize_filename(name)
        Utils.sanitize_filename(name, 'csv')
      end

      def add_task_rows(csv, task)
        # Parent task
        csv << [
          'task',                          # TYPE
          task.title,                      # CONTENT
          task.body || '',                 # DESCRIPTION
          task.todoist_priority,           # PRIORITY
          1,                               # INDENT (parent)
          '',                              # AUTHOR
          '',                              # RESPONSIBLE
          task.due_date || '',             # DATE
          'en',                            # DATE_LANG
          task.due_timezone || ''          # TIMEZONE
        ]

        # Subtasks (checklist items)
        task.checklist_items.each do |item|
          csv << [
            'task',                        # TYPE
            item['displayName'],           # CONTENT
            '',                            # DESCRIPTION
            task.todoist_priority,         # PRIORITY (inherit from parent)
            2,                             # INDENT (subtask)
            '',                            # AUTHOR
            '',                            # RESPONSIBLE
            '',                            # DATE
            'en',                          # DATE_LANG
            ''                             # TIMEZONE
          ]
        end
      end

      def total_task_count(tasks)
        tasks.sum(&:total_task_count)
      end
    end
  end
end
