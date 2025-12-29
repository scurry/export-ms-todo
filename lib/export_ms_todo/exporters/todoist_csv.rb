# frozen_string_literal: true

# lib/export_ms_todo/exporters/todoist_csv.rb
require 'csv'
require_relative 'task_chunker'
require_relative '../utils'
require_relative '../recurrence_mapper'

module ExportMsTodo
  module Exporters
    class TodoistCSV
      MAX_TASKS_PER_FILE = 300

      TODOIST_HEADERS = %w[
        TYPE CONTENT DESCRIPTION PRIORITY INDENT
        AUTHOR RESPONSIBLE DATE DATE_LANG TIMEZONE
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
            TaskChunker.new(list, tasks, self, MAX_TASKS_PER_FILE).export
          end
        end
      end

      def generate_csv(_list, tasks)
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
        # Determine DATE field - recurrence takes precedence over one-time due date
        date_value = if task.recurrence
                       RecurrenceMapper.new.map(task.recurrence)
                     else
                       task.due_date || ''
                     end

        # Parent task
        csv << [
          'task',                          # TYPE
          task.title,                      # CONTENT
          task.body || '',                 # DESCRIPTION
          task.todoist_priority,           # PRIORITY
          1,                               # INDENT (parent)
          '',                              # AUTHOR
          '',                              # RESPONSIBLE
          date_value,                      # DATE
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
