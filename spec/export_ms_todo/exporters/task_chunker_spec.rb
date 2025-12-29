# frozen_string_literal: true

# spec/export_ms_todo/exporters/task_chunker_spec.rb
require 'spec_helper'
require 'export_ms_todo/exporters/task_chunker'
require 'export_ms_todo/exporters/todoist_csv'
require 'export_ms_todo/task'

RSpec.describe ExportMsTodo::Exporters::TaskChunker do
  let(:list) { { 'id' => 'list1', 'displayName' => 'Large Project' } }
  let(:exporter) { ExportMsTodo::Exporters::TodoistCSV.new }

  def build_task(title, subtask_count = 0)
    checklist = Array.new(subtask_count) { { 'displayName' => 'Subtask' } }
    ExportMsTodo::Task.new({
                             'title' => title,
                             'checklistItems' => checklist,
                             'listName' => 'Large Project'
                           })
  end

  describe '#export' do
    it 'splits tasks into 300-task chunks' do
      tasks = Array.new(450) { build_task('Task') }
      chunker = described_class.new(list, tasks, exporter)

      result = chunker.export

      expect(result.size).to eq(2)
      expect(result[0][:filename]).to eq('Large-Project-1.csv')
      expect(result[1][:filename]).to eq('Large-Project-2.csv')
      expect(result[0][:part]).to eq(1)
      expect(result[0][:total_parts]).to eq(2)
    end

    it 'keeps parent task and subtasks together' do
      # 280 simple tasks + 1 task with 50 subtasks = 331 total
      simple_tasks = Array.new(280) { build_task('Simple') }
      complex_task = build_task('Complex', 50) # 1 + 50 = 51 rows

      tasks = simple_tasks + [complex_task]
      chunker = described_class.new(list, tasks, exporter)

      result = chunker.export

      # Should NOT split complex task from its subtasks
      # First chunk: 280 tasks
      # Second chunk: 1 task + 50 subtasks = 51 rows
      expect(result.size).to eq(2)

      # Verify complex task is intact in second file
      csv2 = CSV.parse(result[1][:content], headers: true)
      complex_rows = csv2.select { |row| row['CONTENT'] == 'Complex' || row['INDENT'] == '2' }
      expect(complex_rows.size).to eq(51)
    end

    it 'handles edge case of single task with many subtasks' do
      task_with_many_subtasks = build_task('Mega Task', 350)
      chunker = described_class.new(list, [task_with_many_subtasks], exporter)

      # Should warn but still export
      expect { chunker.export }.to output(/exceeds 300 limit/).to_stderr

      result = chunker.export
      expect(result.size).to eq(1) # One chunk with 351 rows
    end

    it 'generates valid CSV content for each chunk' do
      tasks = Array.new(450) { build_task('Task') }
      chunker = described_class.new(list, tasks, exporter)

      result = chunker.export

      result.each do |file|
        csv = CSV.parse(file[:content], headers: true)
        expect(csv.headers).to include('TYPE', 'CONTENT', 'PRIORITY')
        expect(csv).not_to be_empty
      end
    end

    it 'distributes tasks evenly across chunks' do
      tasks = Array.new(550) { build_task('Task') }
      chunker = described_class.new(list, tasks, exporter)

      result = chunker.export

      expect(result.size).to eq(2)

      # First chunk should be ~300, second ~250
      csv1 = CSV.parse(result[0][:content], headers: true)
      csv2 = CSV.parse(result[1][:content], headers: true)

      expect(csv1.size).to be <= 300
      expect(csv2.size).to be <= 300
      expect(csv1.size + csv2.size).to eq(550)
    end
  end
end
