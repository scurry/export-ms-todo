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
      fetch_paged_lists('/me/todo/lists')
    end

    private

    def fetch_paged_lists(url)
      response = @client.get(url)
      data = JSON.parse(response.body)

      lists = data['value'].select do |list|
        ['none', 'defaultList'].include?(list['wellknownListName'])
      end

      if data['@odata.nextLink']
        lists + fetch_paged_lists(data['@odata.nextLink'])
      else
        lists
      end
    end

    def fetch_tasks_for_list(list_id, skip = 0)
      url = "/me/todo/lists/#{list_id}/tasks"
      url += "?$skip=#{skip}" if skip > 0

      response = @client.get(url)
      data = JSON.parse(response.body)

      tasks = data['value'].select { |t| t['status'] != 'completed' }

      if data['@odata.nextLink']
        next_skip = data['@odata.nextLink'].match(/\$skip=(\d+)/)[1].to_i
        tasks + fetch_tasks_for_list(list_id, next_skip)
      else
        tasks
      end
    end

    def fetch_checklist_items(list_id, task_id)
      url = "/me/todo/lists/#{list_id}/tasks/#{task_id}/checklistItems"
      response = @client.get(url)
      data = JSON.parse(response.body)
      data['value'] || []
    rescue
      []
    end
  end
end
