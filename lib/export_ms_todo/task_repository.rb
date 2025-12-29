# frozen_string_literal: true

# lib/export_ms_todo/task_repository.rb
require 'json'
require_relative 'task'

module ExportMsTodo
  class TaskRepository
    def initialize(client)
      @client = client
    end

    def fetch_all_tasks
      lists = fetch_lists

      lists.map do |list|
        tasks_data = fetch_tasks_for_list(list['id'])

        tasks = tasks_data.map do |task_data|
          checklist = fetch_checklist_items(list['id'], task_data['id'])

          Task.new(task_data.merge(
                     'checklistItems' => checklist,
                     'listName' => list['displayName'],
                     'listId' => list['id']
                   ))
        end

        { list: list, tasks: tasks }
      end
    end

    def fetch_lists
      fetch_collection('/me/todo/lists').select do |list|
        %w[none defaultList].include?(list['wellknownListName'])
      end
    end

    private

    def fetch_collection(url)
      response = @client.get(url)
      data = JSON.parse(response.body)
      items = data['value'] || []

      if data['@odata.nextLink']
        items + fetch_collection(data['@odata.nextLink'])
      else
        items
      end
    end

    def fetch_tasks_for_list(list_id)
      fetch_collection("/me/todo/lists/#{list_id}/tasks").reject do |t|
        t['status'] == 'completed'
      end
    end

    def fetch_checklist_items(list_id, task_id)
      url = "/me/todo/lists/#{list_id}/tasks/#{task_id}/checklistItems"
      response = @client.get(url)
      data = JSON.parse(response.body)
      data['value'] || []
    rescue ExportMsTodo::Error => e
      # Re-raise critical errors
      raise e if e.is_a?(AuthenticationError) || e.is_a?(RateLimitError)

      # Handle 404 (Task not found) gracefully
      if e.message.include?('404')
        warn "⚠️  Task #{task_id} not found when fetching checklist (skipping checklist)"
        return []
      end

      raise e
    end
  end
end
