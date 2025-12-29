# frozen_string_literal: true

# spec/export_ms_todo/exporters/json_spec.rb
require 'spec_helper'
require 'export_ms_todo/exporters/json'
require 'export_ms_todo/task'
require 'json'

RSpec.describe ExportMsTodo::Exporters::JSON do
  subject(:exporter) { described_class.new }

  let(:list) { { 'id' => 'list1', 'displayName' => 'Work' } }
  let(:task) do
    ExportMsTodo::Task.new({
                             'id' => 'task1',
                             'title' => 'Review PR',
                             'body' => 'Check authentication',
                             'importance' => 'high',
                             'checklistItems' => [
                               { 'displayName' => 'Check tests' }
                             ],
                             'listName' => 'Work'
                           })
  end
  let(:grouped_tasks) { [{ list: list, tasks: [task] }] }

  describe '#export' do
    it 'generates JSON output' do
      result = exporter.export(grouped_tasks)

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first[:filename]).to eq('Work.json')
      expect(result.first[:content]).to be_a(String)
    end

    it 'produces valid JSON' do
      result = exporter.export(grouped_tasks)
      json_content = result.first[:content]

      expect { JSON.parse(json_content) }.not_to raise_error
    end

    it 'includes all task data' do
      result = exporter.export(grouped_tasks)
      data = JSON.parse(result.first[:content])

      expect(data).to have_key('list')
      expect(data).to have_key('tasks')

      expect(data['list']['displayName']).to eq('Work')
      expect(data['tasks'].size).to eq(1)

      task_data = data['tasks'].first
      expect(task_data['title']).to eq('Review PR')
      expect(task_data['body']).to eq('Check authentication')
      expect(task_data['importance']).to eq('high')
      expect(task_data['checklist_items'].size).to eq(1)
    end

    it 'includes metadata' do
      result = exporter.export(grouped_tasks)
      data = JSON.parse(result.first[:content])

      expect(data).to have_key('exported_at')
      expect(data).to have_key('task_count')
      expect(data['task_count']).to eq(1)
    end

    it 'pretty prints JSON' do
      result = exporter.export(grouped_tasks)
      json_content = result.first[:content]

      # Pretty printed JSON has newlines and indentation
      expect(json_content).to include("\n")
      expect(json_content).to match(/\s{2,}/)
    end

    it 'handles multiple lists' do
      list2 = { 'id' => 'list2', 'displayName' => 'Personal' }
      task2 = ExportMsTodo::Task.new({ 'title' => 'Buy milk', 'listName' => 'Personal' })

      grouped_tasks = [
        { list: list, tasks: [task] },
        { list: list2, tasks: [task2] }
      ]

      result = exporter.export(grouped_tasks)

      expect(result.size).to eq(2)
      expect(result[0][:filename]).to eq('Work.json')
      expect(result[1][:filename]).to eq('Personal.json')
    end
  end
end
