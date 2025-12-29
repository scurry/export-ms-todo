# spec/export_ms_todo/task_spec.rb
require 'spec_helper'
require 'export_ms_todo/task'

RSpec.describe ExportMsTodo::Task do
  describe '#initialize' do
    it 'creates task from MS Graph API data' do
      data = {
        'id' => 'task-123',
        'title' => 'Buy groceries',
        'body' => { 'content' => 'Milk, eggs, bread' },
        'importance' => 'high',
        'status' => 'notStarted',
        'dueDateTime' => {
          'dateTime' => '2025-01-20T10:00:00',
          'timeZone' => 'America/New_York'
        },
        'checklistItems' => [
          { 'displayName' => 'Milk', 'isChecked' => false },
          { 'displayName' => 'Eggs', 'isChecked' => false }
        ],
        'listName' => 'Shopping',
        'listId' => 'list-456'
      }

      task = described_class.new(data)

      expect(task.id).to eq('task-123')
      expect(task.title).to eq('Buy groceries')
      expect(task.body).to eq('Milk, eggs, bread')
      expect(task.importance).to eq('high')
      expect(task.due_date).to eq('2025-01-20T10:00:00')
      expect(task.due_timezone).to eq('America/New_York')
      expect(task.checklist_items.size).to eq(2)
      expect(task.list_name).to eq('Shopping')
    end
  end

  describe '#todoist_priority' do
    it 'maps low/normal importance to priority 4' do
      task = described_class.new('importance' => 'low')
      expect(task.todoist_priority).to eq(4)

      task = described_class.new('importance' => 'normal')
      expect(task.todoist_priority).to eq(4)
    end

    it 'maps high importance to priority 1' do
      task = described_class.new('importance' => 'high')
      expect(task.todoist_priority).to eq(1)
    end

    it 'defaults to priority 4 for unknown importance' do
      task = described_class.new('importance' => 'unknown')
      expect(task.todoist_priority).to eq(4)
    end
  end

  describe '#subtask_count' do
    it 'returns count of checklist items' do
      task = described_class.new('checklistItems' => [{}, {}, {}])
      expect(task.subtask_count).to eq(3)
    end
  end

  describe '#total_task_count' do
    it 'returns 1 + subtask count' do
      task = described_class.new('checklistItems' => [{}, {}])
      expect(task.total_task_count).to eq(3)
    end
  end
end
