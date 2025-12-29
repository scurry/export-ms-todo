# lib/export_ms_todo/task.rb
module ExportMsTodo
  class Task
    attr_reader :id, :title, :body, :importance, :status,
                :due_date, :due_timezone, :recurrence,
                :checklist_items, :list_name, :list_id,
                :created_at, :updated_at

    PRIORITY_MAP = {
      'low' => 4,
      'normal' => 4,
      'high' => 1
    }.freeze

    def initialize(data)
      @id = data['id']
      @title = data['title']
      @body = data.dig('body', 'content') || data['body']
      @importance = data['importance']
      @status = data['status']
      @recurrence = data['recurrence']
      @list_name = data['listName']
      @list_id = data['listId']
      @created_at = data['createdDateTime']
      @updated_at = data['lastModifiedDateTime']

      if data['dueDateTime']
        @due_date = data['dueDateTime']['dateTime']
        @due_timezone = data['dueDateTime']['timeZone']
      end

      @checklist_items = data['checklistItems'] || []
    end

    def todoist_priority
      PRIORITY_MAP[@importance] || 4
    end

    def subtask_count
      @checklist_items.size
    end

    def total_task_count
      1 + subtask_count
    end
  end
end
