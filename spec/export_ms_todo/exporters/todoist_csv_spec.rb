# frozen_string_literal: true

# spec/export_ms_todo/exporters/todoist_csv_spec.rb
require 'spec_helper'
require 'export_ms_todo/exporters/todoist_csv'
require 'export_ms_todo/task'
require 'csv'

RSpec.describe ExportMsTodo::Exporters::TodoistCSV do
  subject(:exporter) { described_class.new }

  describe '#export' do
    let(:list) { { 'id' => 'list1', 'displayName' => 'Work' } }
    let(:task_data) do
      {
        'id' => 'task1',
        'title' => 'Review PR',
        'body' => 'Check the authentication changes',
        'importance' => 'high',
        'dueDateTime' => {
          'dateTime' => '2025-01-20T10:00:00',
          'timeZone' => 'America/New_York'
        },
        'checklistItems' => [],
        'listName' => 'Work',
        'listId' => 'list1'
      }
    end
    let(:task) { ExportMsTodo::Task.new(task_data) }
    let(:grouped_tasks) { [{ list: list, tasks: [task] }] }

    it 'generates CSV files for each list' do
      result = exporter.export(grouped_tasks)

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first[:filename]).to eq('Work.csv')
      expect(result.first[:content]).to be_a(String)
    end

    it 'includes Todoist CSV headers' do
      result = exporter.export(grouped_tasks)
      csv_content = result.first[:content]

      csv = CSV.parse(csv_content, headers: true)
      expect(csv.headers).to include('TYPE', 'CONTENT', 'PRIORITY', 'INDENT', 'DATE', 'TIMEZONE')
    end

    it 'maps task fields correctly' do
      result = exporter.export(grouped_tasks)
      csv = CSV.parse(result.first[:content], headers: true)

      row = csv.first
      expect(row['TYPE']).to eq('task')
      expect(row['CONTENT']).to eq('Review PR')
      expect(row['DESCRIPTION']).to eq('Check the authentication changes')
      expect(row['PRIORITY']).to eq('1') # high importance
      expect(row['INDENT']).to eq('1')
      expect(row['DATE']).to eq('2025-01-20T10:00:00')
      expect(row['TIMEZONE']).to eq('America/New_York')
    end

    it 'handles tasks with subtasks' do
      task_data['checklistItems'] = [
        { 'displayName' => 'Check tests', 'isChecked' => false },
        { 'displayName' => 'Check docs', 'isChecked' => false }
      ]
      task = ExportMsTodo::Task.new(task_data)
      grouped_tasks = [{ list: list, tasks: [task] }]

      result = exporter.export(grouped_tasks)
      csv = CSV.parse(result.first[:content], headers: true)

      expect(csv.size).to eq(3) # 1 parent + 2 subtasks

      # Parent task
      expect(csv[0]['CONTENT']).to eq('Review PR')
      expect(csv[0]['INDENT']).to eq('1')

      # Subtasks
      expect(csv[1]['CONTENT']).to eq('Check tests')
      expect(csv[1]['INDENT']).to eq('2')
      expect(csv[2]['CONTENT']).to eq('Check docs')
      expect(csv[2]['INDENT']).to eq('2')
    end

    it 'escapes special characters in titles' do
      task_data['title'] = 'Buy milk, eggs, and bread'
      task = ExportMsTodo::Task.new(task_data)

      result = exporter.export([{ list: list, tasks: [task] }])
      csv = CSV.parse(result.first[:content], headers: true)

      expect(csv.first['CONTENT']).to eq('Buy milk, eggs, and bread')
    end

    it 'escapes quotes in content' do
      task_data['title'] = 'Task with "quotes" inside'
      task = ExportMsTodo::Task.new(task_data)

      result = exporter.export([{ list: list, tasks: [task] }])
      csv = CSV.parse(result.first[:content], headers: true)

      # CSV should properly escape quotes by doubling them
      expect(csv.first['CONTENT']).to eq('Task with "quotes" inside')
    end

    it 'handles newlines in descriptions' do
      task_data['body'] = "Line 1\nLine 2\nLine 3"
      task = ExportMsTodo::Task.new(task_data)

      result = exporter.export([{ list: list, tasks: [task] }])
      csv = CSV.parse(result.first[:content], headers: true)

      expect(csv.first['DESCRIPTION']).to eq("Line 1\nLine 2\nLine 3")
    end

    it 'uses simple export for lists under 300 tasks' do
      tasks = Array.new(250) { task }
      grouped_tasks = [{ list: list, tasks: tasks }]

      result = exporter.export(grouped_tasks)

      expect(result.size).to eq(1)
      expect(result.first[:filename]).to eq('Work.csv')
    end

    it 'delegates to TaskChunker for lists over 300 tasks' do
      tasks = Array.new(450) { task }
      grouped_tasks = [{ list: list, tasks: tasks }]

      result = exporter.export(grouped_tasks)

      # Should split into multiple files
      expect(result.size).to eq(2)
      expect(result[0][:filename]).to eq('Work-1.csv')
      expect(result[1][:filename]).to eq('Work-2.csv')
    end

    describe 'recurrence patterns' do
      it 'maps recurrence to DATE field' do
        task_data['recurrence'] = {
          'pattern' => { 'type' => 'daily', 'interval' => 1 }
        }
        task = ExportMsTodo::Task.new(task_data)

        result = exporter.export([{ list: list, tasks: [task] }])
        csv = CSV.parse(result.first[:content], headers: true)

        expect(csv.first['DATE']).to eq('every day')
      end

      it 'handles complex recurrence patterns' do
        task_data['recurrence'] = {
          'pattern' => {
            'type' => 'weekly',
            'interval' => 2,
            'daysOfWeek' => %w[monday wednesday]
          }
        }
        task = ExportMsTodo::Task.new(task_data)

        result = exporter.export([{ list: list, tasks: [task] }])
        csv = CSV.parse(result.first[:content], headers: true)

        expect(csv.first['DATE']).to eq('every 2 weeks on Monday and Wednesday')
      end

      it 'prefers recurrence over due date' do
        task_data['dueDateTime'] = {
          'dateTime' => '2025-01-20T10:00:00',
          'timeZone' => 'America/New_York'
        }
        task_data['recurrence'] = {
          'pattern' => { 'type' => 'weekly', 'interval' => 1 }
        }
        task = ExportMsTodo::Task.new(task_data)

        result = exporter.export([{ list: list, tasks: [task] }])
        csv = CSV.parse(result.first[:content], headers: true)

        # Recurrence should override one-time due date
        expect(csv.first['DATE']).to eq('every week')
      end
    end
  end

  describe '#sanitize_filename' do
    it 'removes invalid characters' do
      result = exporter.send(:sanitize_filename, 'Work/Project: #1')
      expect(result).to eq('Work-Project-1.csv')
    end

    it 'handles unicode characters' do
      result = exporter.send(:sanitize_filename, 'Café ☕ Tasks')
      expect(result).to match(/Caf.*Tasks\.csv/)
    end
  end
end
