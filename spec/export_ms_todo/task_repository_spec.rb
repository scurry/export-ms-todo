# frozen_string_literal: true

# spec/export_ms_todo/task_repository_spec.rb
require 'spec_helper'
require 'export_ms_todo/task_repository'
require 'export_ms_todo/graph_client'

RSpec.describe ExportMsTodo::TaskRepository do
  subject(:repo) { described_class.new(client) }

  let(:client) { instance_double(ExportMsTodo::GraphClient) }

  describe '#fetch_all_tasks' do
    let(:list_response) do
      double(body: { 'value' => [
        { 'id' => 'list1', 'displayName' => 'Work', 'wellknownListName' => 'none' }
      ] }.to_json)
    end

    let(:tasks_response) do
      double(body: { 'value' => [
        { 'id' => 'task1', 'title' => 'Task', 'status' => 'notStarted' }
      ] }.to_json)
    end

    let(:checklist_response) do
      double(body: { 'value' => [] }.to_json)
    end

    before do
      allow(client).to receive(:get).with('/me/todo/lists').and_return(list_response)
      allow(client).to receive(:get).with('/me/todo/lists/list1/tasks').and_return(tasks_response)
      allow(client).to receive(:get).with(%r{/checklistItems$}).and_return(checklist_response)
    end

    it 'fetches lists and tasks' do
      result = repo.fetch_all_tasks
      expect(result).to be_an(Array)
      expect(result.first[:list]['displayName']).to eq('Work')
      expect(result.first[:tasks].first).to be_a(ExportMsTodo::Task)
    end
  end
end
