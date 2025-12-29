# spec/integration/export_flow_spec.rb
require 'spec_helper'
require 'export_ms_todo'
require 'export_ms_todo/graph_client'
require 'export_ms_todo/task_repository'
require 'export_ms_todo/exporters/todoist_csv'
require 'export_ms_todo/exporters/json'

RSpec.describe 'Full export flow', :integration do
  let(:token) { 'Bearer test_integration_token' }

  describe 'CSV export flow' do
    it 'fetches tasks and exports to CSV' do
      # Mock the API responses
      lists_response = double(body: {
        'value' => [
          {
            'id' => 'list-1',
            'displayName' => 'Work Tasks',
            'wellknownListName' => 'none'
          }
        ]
      }.to_json)

      tasks_response = double(body: {
        'value' => [
          {
            'id' => 'task-1',
            'title' => 'Complete project',
            'body' => { 'content' => 'Finish the implementation' },
            'importance' => 'high',
            'status' => 'notStarted',
            'dueDateTime' => {
              'dateTime' => '2025-01-15T10:00:00',
              'timeZone' => 'America/New_York'
            }
          },
          {
            'id' => 'task-2',
            'title' => 'Weekly standup',
            'importance' => 'normal',
            'status' => 'notStarted',
            'recurrence' => {
              'pattern' => {
                'type' => 'weekly',
                'interval' => 1,
                'daysOfWeek' => ['monday']
              }
            }
          }
        ]
      }.to_json)

      checklist_response = double(body: {
        'value' => [
          { 'displayName' => 'Review code', 'isChecked' => false },
          { 'displayName' => 'Write tests', 'isChecked' => false }
        ]
      }.to_json)

      # Set up mocks
      client = ExportMsTodo::GraphClient.new(token)
      allow(client).to receive(:get).with('/me/todo/lists').and_return(lists_response)
      allow(client).to receive(:get).with('/me/todo/lists/list-1/tasks').and_return(tasks_response)
      allow(client).to receive(:get).with(/checklistItems/).and_return(checklist_response)

      # Execute the flow
      repo = ExportMsTodo::TaskRepository.new(client)
      grouped_tasks = repo.fetch_all_tasks

      # Verify task fetching
      expect(grouped_tasks.size).to eq(1)
      expect(grouped_tasks.first[:list]['displayName']).to eq('Work Tasks')
      expect(grouped_tasks.first[:tasks].size).to eq(2)

      # Export to CSV
      exporter = ExportMsTodo::Exporters::TodoistCSV.new
      files = exporter.export(grouped_tasks)

      # Verify CSV export
      expect(files.size).to eq(1)
      expect(files.first[:filename]).to eq('Work-Tasks.csv')

      csv_content = files.first[:content]
      csv = CSV.parse(csv_content, headers: true)

      # First task (with subtasks)
      expect(csv[0]['CONTENT']).to eq('Complete project')
      expect(csv[0]['PRIORITY']).to eq('1')  # high
      expect(csv[0]['DATE']).to eq('2025-01-15T10:00:00')
      expect(csv[0]['INDENT']).to eq('1')

      # Subtasks
      expect(csv[1]['CONTENT']).to eq('Review code')
      expect(csv[1]['INDENT']).to eq('2')
      expect(csv[2]['CONTENT']).to eq('Write tests')
      expect(csv[2]['INDENT']).to eq('2')

      # Recurring task
      expect(csv[3]['CONTENT']).to eq('Weekly standup')
      expect(csv[3]['DATE']).to eq('every Monday')
      expect(csv[3]['PRIORITY']).to eq('4')  # normal
    end
  end

  describe 'JSON export flow' do
    it 'fetches tasks and exports to JSON' do
      lists_response = double(body: {
        'value' => [
          {
            'id' => 'list-1',
            'displayName' => 'Personal',
            'wellknownListName' => 'defaultList'
          }
        ]
      }.to_json)

      tasks_response = double(body: {
        'value' => [
          {
            'id' => 'task-1',
            'title' => 'Buy groceries',
            'importance' => 'normal',
            'status' => 'notStarted'
          }
        ]
      }.to_json)

      checklist_response = double(body: { 'value' => [] }.to_json)

      client = ExportMsTodo::GraphClient.new(token)
      allow(client).to receive(:get).with('/me/todo/lists').and_return(lists_response)
      allow(client).to receive(:get).with('/me/todo/lists/list-1/tasks').and_return(tasks_response)
      allow(client).to receive(:get).with(/checklistItems/).and_return(checklist_response)

      repo = ExportMsTodo::TaskRepository.new(client)
      grouped_tasks = repo.fetch_all_tasks

      exporter = ExportMsTodo::Exporters::JSON.new
      files = exporter.export(grouped_tasks)

      expect(files.size).to eq(1)
      expect(files.first[:filename]).to eq('Personal.json')

      json_data = JSON.parse(files.first[:content])
      expect(json_data['list']['displayName']).to eq('Personal')
      expect(json_data['tasks'].size).to eq(1)
      expect(json_data['tasks'].first['title']).to eq('Buy groceries')
      expect(json_data).to have_key('exported_at')
      expect(json_data).to have_key('task_count')
    end
  end

  describe 'Error handling' do
    it 'handles authentication errors gracefully' do
      client = ExportMsTodo::GraphClient.new('invalid_token')
      allow(client).to receive(:get).and_raise(ExportMsTodo::AuthenticationError, 'Invalid token')

      repo = ExportMsTodo::TaskRepository.new(client)

      expect {
        repo.fetch_all_tasks
      }.to raise_error(ExportMsTodo::AuthenticationError, 'Invalid token')
    end

    it 'handles rate limit errors gracefully' do
      client = ExportMsTodo::GraphClient.new(token)
      allow(client).to receive(:get).and_raise(ExportMsTodo::RateLimitError, 'Rate limited')

      repo = ExportMsTodo::TaskRepository.new(client)

      expect {
        repo.fetch_all_tasks
      }.to raise_error(ExportMsTodo::RateLimitError, 'Rate limited')
    end
  end
end
