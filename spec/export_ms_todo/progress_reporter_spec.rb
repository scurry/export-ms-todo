# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/export_ms_todo/progress_reporter'
require_relative '../../lib/export_ms_todo/task'

RSpec.describe ExportMsTodo::ProgressReporter do
  let(:output) { double('output') }
  let(:reporter) { described_class.new(verbose: false, output: output) }
  let(:verbose_reporter) { described_class.new(verbose: true, output: output) }

  describe '#initialize' do
    it 'initializes with zero counts' do
      expect(reporter.total_tasks_in_ms).to eq(0)
      expect(reporter.exported_count).to eq(0)
      expect(reporter.completed_skipped).to eq(0)
      expect(reporter.failed_count).to eq(0)
    end
  end

  describe '#start_fetching' do
    it 'shows message when lists exist' do
      expect(output).to receive(:say).with('Fetching tasks...', :green)
      reporter.start_fetching(3)
    end

    it 'does not show message when no lists' do
      expect(output).not_to receive(:say)
      reporter.start_fetching(0)
    end
  end

  describe '#fetching_list' do
    context 'in default mode' do
      it 'does not show detailed output' do
        expect(output).not_to receive(:say)
        reporter.fetching_list('Work', 1, 3)
      end
    end

    context 'in verbose mode' do
      it 'shows list progress' do
        expect(output).to receive(:say).with('  → Work (1/3)')
        verbose_reporter.fetching_list('Work', 1, 3)
      end
    end
  end

  describe '#fetched_task' do
    let(:task) { instance_double(ExportMsTodo::Task, title: 'Test task', list_name: 'Work') }

    it 'increments total and exported counts' do
      allow(output).to receive(:say)
      reporter.fetched_task(task, 'Work')

      expect(reporter.total_tasks_in_ms).to eq(1)
      expect(reporter.exported_count).to eq(1)
    end

    context 'in default mode' do
      it 'does not show task details' do
        expect(output).not_to receive(:say)
        reporter.fetched_task(task, 'Work')
      end
    end

    context 'in verbose mode' do
      it 'shows task details' do
        expect(output).to receive(:say).with(/Task: 'Test task'/)
        verbose_reporter.fetched_task(task, 'Work')
      end
    end
  end

  describe '#skipped_completed_task' do
    let(:task) { instance_double(ExportMsTodo::Task, title: 'Done task', list_name: 'Work') }

    before do
      allow(output).to receive(:say)
      reporter.fetched_task(task, 'Work') # First count as exported
    end

    it 'adjusts counts correctly' do
      allow(output).to receive(:say)
      reporter.skipped_completed_task(task)

      expect(reporter.exported_count).to eq(0) # Adjusted down
      expect(reporter.completed_skipped).to eq(1)
    end

    context 'in verbose mode' do
      before do
        verbose_reporter.fetched_task(task, 'Work')
      end

      it 'shows skipped message' do
        expect(output).to receive(:say).with(/Skipped/, :yellow)
        verbose_reporter.skipped_completed_task(task)
      end
    end
  end

  describe '#failed_task' do
    let(:error) { StandardError.new('Network error') }

    before do
      allow(output).to receive(:say)
      reporter.fetching_list('Work', 1, 1)
    end

    it 'increments failed count' do
      reporter.failed_task('task-123', error)
      expect(reporter.failed_count).to eq(1)
    end

    context 'in verbose mode' do
      it 'shows error details' do
        expect(output).to receive(:say).with(/Failed: task-123/, :red)
        expect(output).to receive(:say).with(/Error: Network error/, :red)
        verbose_reporter.failed_task('task-123', error)
      end
    end
  end

  describe '#print_summary' do
    before do
      allow(output).to receive(:say)
      reporter.start_export
      sleep 0.01 # Small delay to ensure duration > 0
    end

    it 'prints header' do
      expect(output).to receive(:say).with(/━{50}/)
      expect(output).to receive(:say).with('Export Summary')
      reporter.print_summary
    end

    it 'shows total tasks' do
      reporter.increment_total_tasks(100)
      expect(output).to receive(:say).with(/Total tasks in MS Todo:\s+100/)
      reporter.print_summary
    end

    it 'shows exported count' do
      reporter.increment_exported(75)
      expect(output).to receive(:say).with(/Exported:\s+75/, :green)
      reporter.print_summary
    end

    it 'shows completed skipped when > 0' do
      reporter.increment_completed_skipped(25)
      expect(output).to receive(:say).with(/Completed.*skipped.*25/, :yellow)
      reporter.print_summary
    end

    it 'shows failed count when > 0' do
      reporter.increment_failed(2)
      expect(output).to receive(:say).with(/Failed:\s+2/, :red)
      expect(output).to receive(:say).with(/2 tasks failed/, :yellow)
      reporter.print_summary
    end

    it 'shows duration' do
      expect(output).to receive(:say).with(/Duration:/)
      reporter.print_summary
    end
  end
end
