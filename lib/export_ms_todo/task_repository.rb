# frozen_string_literal: true

# lib/export_ms_todo/task_repository.rb
require 'json'
require_relative 'task'
require_relative 'null_reporter'

module ExportMsTodo
  class TaskRepository
    def initialize(client, reporter: nil)
      @client = client
      @reporter = reporter || NullReporter.new
    end

    def fetch_all_tasks
      lists = fetch_lists
      @reporter.start_fetching(lists.size)

      lists.map.with_index do |list, idx|
        @reporter.fetching_list(list['displayName'], idx + 1, lists.size)

        tasks_data = fetch_tasks_for_list(list['id'])

        tasks = tasks_data.map do |task_data|
          checklist = fetch_checklist_items(list['id'], task_data['id'])

          task = Task.new(task_data.merge(
                            'checklistItems' => checklist,
                            'listName' => list['displayName'],
                            'listId' => list['id']
                          ))

          @reporter.fetched_task(task, list['displayName'])
          task
        end

        { list: list, tasks: tasks }
      end
    end

    def fetch_lists
      fetch_collection('/me/todo/lists?$top=100').select do |list|
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
      # optimized with server-side filtering and larger page size
      fetch_collection("/me/todo/lists/#{list_id}/tasks?$top=100&$filter=status%20ne%20'completed'")
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
        @reporter.failed_task(task_id, e)
        return []
      end

      raise e
    end
  end
end
