# frozen_string_literal: true

require 'spec_helper'
require 'export_ms_todo/exporters/todoist_csv'
require 'export_ms_todo/task'

RSpec.describe 'CSV special character escaping' do
  let(:exporter) { ExportMsTodo::Exporters::TodoistCSV.new }

  describe 'semicolon in task content' do
    it 'properly escapes semicolons in title' do
      task_data = {
        'id' => '1',
        'title' => 'Fix bug; update docs',
        'body' => 'Description here',
        'importance' => 'normal',
        'status' => 'notStarted',
        'checklistItems' => [],
        'listName' => 'Work',
        'listId' => 'list1'
      }

      task = ExportMsTodo::Task.new(task_data)
      grouped = [{ list: { 'displayName' => 'Work' }, tasks: [task] }]

      csv_content = exporter.export(grouped).first[:content]

      # Parse the CSV back
      parsed = CSV.parse(csv_content, headers: true)
      expect(parsed.first['CONTENT']).to eq('Fix bug; update docs')
    end

    it 'properly escapes semicolons in description' do
      task_data = {
        'id' => '1',
        'title' => 'Task title',
        'body' => 'Step 1; Step 2; Step 3',
        'importance' => 'normal',
        'status' => 'notStarted',
        'checklistItems' => [],
        'listName' => 'Work',
        'listId' => 'list1'
      }

      task = ExportMsTodo::Task.new(task_data)
      grouped = [{ list: { 'displayName' => 'Work' }, tasks: [task] }]

      csv_content = exporter.export(grouped).first[:content]

      # Parse the CSV back
      parsed = CSV.parse(csv_content, headers: true)
      expect(parsed.first['DESCRIPTION']).to eq('Step 1; Step 2; Step 3')
    end

    it 'properly escapes commas in content' do
      task_data = {
        'id' => '1',
        'title' => 'Buy milk, eggs, bread',
        'body' => 'From store A, store B, or store C',
        'importance' => 'normal',
        'status' => 'notStarted',
        'checklistItems' => [],
        'listName' => 'Shopping',
        'listId' => 'list1'
      }

      task = ExportMsTodo::Task.new(task_data)
      grouped = [{ list: { 'displayName' => 'Shopping' }, tasks: [task] }]

      csv_content = exporter.export(grouped).first[:content]

      # Parse the CSV back
      parsed = CSV.parse(csv_content, headers: true)
      expect(parsed.first['CONTENT']).to eq('Buy milk, eggs, bread')
      expect(parsed.first['DESCRIPTION']).to eq('From store A, store B, or store C')
    end

    it 'properly escapes quotes in content' do
      task_data = {
        'id' => '1',
        'title' => 'Review "Project X" docs',
        'body' => 'Check the "important" section',
        'importance' => 'normal',
        'status' => 'notStarted',
        'checklistItems' => [],
        'listName' => 'Work',
        'listId' => 'list1'
      }

      task = ExportMsTodo::Task.new(task_data)
      grouped = [{ list: { 'displayName' => 'Work' }, tasks: [task] }]

      csv_content = exporter.export(grouped).first[:content]

      # Parse the CSV back
      parsed = CSV.parse(csv_content, headers: true)
      expect(parsed.first['CONTENT']).to eq('Review "Project X" docs')
      expect(parsed.first['DESCRIPTION']).to eq('Check the "important" section')
    end
  end
end
