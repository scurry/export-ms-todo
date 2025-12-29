# lib/export_ms_todo/exporters/json.rb
require 'json'
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class JSON
      def export(grouped_tasks)
        grouped_tasks.map do |group|
          list = group[:list]
          tasks = group[:tasks]

          {
            filename: Utils.sanitize_filename(list['displayName'], 'json'),
            content: generate_json(list, tasks)
          }
        end
      end

      private

      def generate_json(list, tasks)
        data = {
          list: {
            id: list['id'],
            displayName: list['displayName']
          },
          tasks: tasks.map { |task| task_to_hash(task) },
          task_count: tasks.size,
          exported_at: Time.now.iso8601
        }

        ::JSON.pretty_generate(data)
      end

      def task_to_hash(task)
        {
          id: task.id,
          title: task.title,
          body: task.body,
          importance: task.importance,
          status: task.status,
          due_date: task.due_date,
          due_timezone: task.due_timezone,
          recurrence: task.recurrence,
          checklist_items: task.checklist_items,
          list_name: task.list_name,
          list_id: task.list_id,
          created_at: task.created_at,
          updated_at: task.updated_at,
          todoist_priority: task.todoist_priority,
          subtask_count: task.subtask_count
        }
      end
    end
  end
end
