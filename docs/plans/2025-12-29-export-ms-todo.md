# Export MS Todo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Ruby CLI and API tool that exports Microsoft To Do tasks to Todoist CSV format, handling subtasks, recurrence, and large lists.

**Architecture:** Monorepo with shared business logic (lib/), Thor CLI (bin/), and Sinatra API (api/). MS Graph API client fetches tasks, exporters generate CSV/JSON, TaskChunker handles >300 task lists.

**Tech Stack:** Ruby 3.x, Thor (CLI), Sinatra (API), HTTParty (HTTP client), RubyZip (ZIP generation), RSpec (testing), VCR (API mocking), Dotenv (env vars)

---

## Task 1: Project Setup

**Files:**
- Create: `Gemfile`
- Create: `.ruby-version`
- Create: `.gitignore`
- Create: `.env.example`
- Create: `README.md`

**Step 1: Create Gemfile**

```ruby
# Gemfile
source 'https://rubygems.org'

ruby '~> 3.2'

gem 'thor', '~> 1.3'
gem 'sinatra', '~> 4.0'
gem 'httparty', '~> 0.21'
gem 'rubyzip', '~> 2.3'
gem 'dotenv', '~> 3.0'
gem 'puma', '~> 6.4'

group :development, :test do
  gem 'rspec', '~> 3.13'
  gem 'rack-test', '~> 2.1'
  gem 'vcr', '~> 6.2'
  gem 'webmock', '~> 3.23'
  gem 'pry', '~> 0.14'
end
```

**Step 2: Create .ruby-version**

```
3.2.0
```

**Step 3: Create .gitignore**

```
.env
*.zip
*.csv
*.gem
.bundle/
vendor/bundle/
.rspec_status
coverage/
.byebug_history
.pry_history
```

**Step 4: Create .env.example**

```bash
# Get your token from: https://developer.microsoft.com/en-us/graph/graph-explorer
# Sign in, select "my To Do task lists", consent to Tasks.ReadWrite permission
# Copy the access token from the "Access token" tab

MS_TODO_TOKEN=Bearer your_token_here
```

**Step 5: Create basic README**

```markdown
# Export MS Todo

Export Microsoft To Do tasks to Todoist CSV format.

## Quick Start

```bash
# Install dependencies
bundle install

# Set up your token
cp .env.example .env
# Edit .env and add your MS Graph token

# Run export
bundle exec export-ms-todo
```

## Development

```bash
# Run tests
bundle exec rspec

# Start API server
bundle exec rackup api/config.ru -p 3000
```

## License

GPL v3.0 (matching source Java project)
```

**Step 6: Install dependencies**

Run: `bundle install`
Expected: All gems installed successfully

**Step 7: Commit**

```bash
git init
git add .
git commit -m "chore: initial project setup with dependencies"
```

---

## Task 2: Core Directory Structure

**Files:**
- Create: `lib/export_ms_todo.rb`
- Create: `lib/export_ms_todo/version.rb`
- Create: `lib/export_ms_todo/utils.rb`
- Create: `spec/spec_helper.rb`

**Step 1: Create lib/export_ms_todo/version.rb**

```ruby
# lib/export_ms_todo/version.rb
module ExportMsTodo
  VERSION = '0.1.0'
end
```

**Step 2: Create lib/export_ms_todo.rb**

```ruby
# lib/export_ms_todo.rb
require_relative 'export_ms_todo/version'
require_relative 'export_ms_todo/utils'
require_relative 'export_ms_todo/config'
require_relative 'export_ms_todo/task'
require_relative 'export_ms_todo/graph_client'
require_relative 'export_ms_todo/task_repository'
require_relative 'export_ms_todo/recurrence_mapper'

module ExportMsTodo
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
  class ValidationError < Error; end
end
```

**Step 3: Create lib/export_ms_todo/utils.rb**

```ruby
# lib/export_ms_todo/utils.rb
module ExportMsTodo
  module Utils
    def self.sanitize_filename(name, extension)
      sanitized = name.gsub(/[^\w\s\-]/, '-')
      sanitized = sanitized.gsub(/\s+/, '-')
      sanitized = sanitized.gsub(/-+/, '-')
      "#{sanitized}.#{extension}"
    end
  end
end
```

**Step 4: Create spec/spec_helper.rb**

```ruby
# spec/spec_helper.rb
require 'bundler/setup'
require 'export_ms_todo'
require 'vcr'
require 'webmock/rspec'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/.rspec_status'
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<MS_GRAPH_TOKEN>') { ENV['MS_TODO_TOKEN'] }
end
```

**Step 5: Create directory structure**

Run: `mkdir -p lib/export_ms_todo/{exporters,} spec/{fixtures/vcr_cassettes,} bin api config`

**Step 6: Commit**

```bash
git add .
git commit -m "chore: create core directory structure and module"
```

---

## Task 3: Task Model (TDD)

**Files:**
- Create: `spec/export_ms_todo/task_spec.rb`
- Create: `lib/export_ms_todo/task.rb`

**Step 1: Write failing test for Task model**

```ruby
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/task_spec.rb`
Expected: LoadError - cannot load such file 'export_ms_todo/task'

**Step 3: Write minimal Task implementation**

```ruby
# lib/export_ms_todo/task.rb
module ExportMsTodo
  class Task
    attr_reader :id, :title, :body, :importance, :status,
                :due_date, :due_timezone, :recurrence,
                :checklist_items, :list_name, :list_id,
                :created_at, :updated_at

    PRIORITY_MAP = {
      'low' => 4,
      'normal' => 4,
      'high' => 1
    }.freeze

    def initialize(data)
      @id = data['id']
      @title = data['title']
      @body = data.dig('body', 'content') || data['body']
      @importance = data['importance']
      @status = data['status']
      @recurrence = data['recurrence']
      @list_name = data['listName']
      @list_id = data['listId']
      @created_at = data['createdDateTime']
      @updated_at = data['lastModifiedDateTime']

      if data['dueDateTime']
        @due_date = data['dueDateTime']['dateTime']
        @due_timezone = data['dueDateTime']['timeZone']
      end

      @checklist_items = data['checklistItems'] || []
    end

    def todoist_priority
      PRIORITY_MAP[@importance] || 4
    end

    def subtask_count
      @checklist_items.size
    end

    def total_task_count
      1 + subtask_count
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/task_spec.rb`
Expected: All tests pass (8 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/export_ms_todo/task.rb spec/export_ms_todo/task_spec.rb
git commit -m "feat: add Task model with todoist priority mapping"
```

---

## Task 4: Recurrence Mapper (TDD)

**Files:**
- Create: `spec/export_ms_todo/recurrence_mapper_spec.rb`
- Create: `lib/export_ms_todo/recurrence_mapper.rb`

**Step 1: Write failing tests for recurrence patterns**

```ruby
# spec/export_ms_todo/recurrence_mapper_spec.rb
require 'spec_helper'
require 'export_ms_todo/recurrence_mapper'

RSpec.describe ExportMsTodo::RecurrenceMapper do
  subject(:mapper) { described_class.new }

  describe '#map' do
    context 'daily patterns' do
      it 'maps daily recurrence' do
        recurrence = { 'pattern' => { 'type' => 'daily', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every day')
      end

      it 'maps every N days' do
        recurrence = { 'pattern' => { 'type' => 'daily', 'interval' => 3 } }
        expect(mapper.map(recurrence)).to eq('every 3 days')
      end
    end

    context 'weekly patterns' do
      it 'maps weekly recurrence' do
        recurrence = { 'pattern' => { 'type' => 'weekly', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every week')
      end

      it 'maps every N weeks' do
        recurrence = { 'pattern' => { 'type' => 'weekly', 'interval' => 2 } }
        expect(mapper.map(recurrence)).to eq('every 2 weeks')
      end

      it 'maps specific days of week' do
        recurrence = {
          'pattern' => {
            'type' => 'weekly',
            'interval' => 1,
            'daysOfWeek' => ['monday', 'wednesday', 'friday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every Monday and Wednesday and Friday')
      end

      it 'maps every N weeks on specific days' do
        recurrence = {
          'pattern' => {
            'type' => 'weekly',
            'interval' => 2,
            'daysOfWeek' => ['tuesday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every 2 weeks on Tuesday')
      end
    end

    context 'monthly patterns' do
      it 'maps monthly on specific day' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 1,
            'dayOfMonth' => 15
          }
        }
        expect(mapper.map(recurrence)).to eq('every month on the 15')
      end

      it 'maps every N months on specific day' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 3,
            'dayOfMonth' => 1
          }
        }
        expect(mapper.map(recurrence)).to eq('every 3 months on the 1')
      end

      it 'maps last day of month' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 1,
            'dayOfMonth' => 31
          }
        }
        expect(mapper.map(recurrence)).to eq('every month on the last day')
      end

      it 'maps relative monthly (first Monday)' do
        recurrence = {
          'pattern' => {
            'type' => 'relativeMonthly',
            'interval' => 1,
            'index' => 'first',
            'daysOfWeek' => ['monday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every first Monday')
      end

      it 'maps last Friday of month' do
        recurrence = {
          'pattern' => {
            'type' => 'relativeMonthly',
            'interval' => 1,
            'index' => 'last',
            'daysOfWeek' => ['friday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every last Friday')
      end
    end

    context 'yearly patterns' do
      it 'maps yearly recurrence' do
        recurrence = { 'pattern' => { 'type' => 'absoluteYearly', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every year')
      end

      it 'maps every N years' do
        recurrence = { 'pattern' => { 'type' => 'absoluteYearly', 'interval' => 2 } }
        expect(mapper.map(recurrence)).to eq('every 2 years')
      end
    end

    context 'unknown patterns' do
      it 'handles unknown pattern types gracefully' do
        recurrence = { 'pattern' => { 'type' => 'unknownPattern', 'interval' => 1 } }

        expect { mapper.map(recurrence) }.not_to raise_error
        expect(mapper.map(recurrence)).to match(/every/)
      end

      it 'logs warning for unknown patterns' do
        recurrence = { 'pattern' => { 'type' => 'customWeird' } }

        expect { mapper.map(recurrence) }.to output(/Unknown recurrence pattern/).to_stderr
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/recurrence_mapper_spec.rb`
Expected: LoadError - cannot load such file

**Step 3: Write RecurrenceMapper implementation**

```ruby
# lib/export_ms_todo/recurrence_mapper.rb
module ExportMsTodo
  class RecurrenceMapper
    def initialize
      @recurrence = nil
    end

    def map(recurrence)
      @recurrence = recurrence
      pattern_type = @recurrence.dig('pattern', 'type')

      return fallback_mapping unless pattern_type

      method_name = "map_#{pattern_type}"
      if respond_to?(method_name, true)
        send(method_name)
      else
        warn "Unknown recurrence pattern: #{pattern_type}"
        fallback_mapping
      end
    end

    private

    def pattern
      @recurrence['pattern']
    end

    def interval
      pattern['interval'] || 1
    end

    def days_of_week
      pattern['daysOfWeek'] || []
    end

    def map_daily
      interval == 1 ? 'every day' : "every #{interval} days"
    end

    def map_weekly
      base = interval == 1 ? 'every week' : "every #{interval} weeks"

      if days_of_week.any?
        days = days_of_week.map(&:capitalize).join(' and ')
        return "every #{days}" if interval == 1
        return "#{base} on #{days}"
      end

      base
    end

    def map_absoluteMonthly
      day = pattern['dayOfMonth']

      # Last day of month heuristic (28-31)
      if day >= 28
        return 'every month on the last day' if interval == 1
        return "every #{interval} months on the last day"
      end

      interval == 1 ? "every month on the #{day}" : "every #{interval} months on the #{day}"
    end

    def map_relativeMonthly
      index = pattern['index']  # first, second, third, fourth, last

      # "Last day of month" (no specific day of week)
      if index == 'last' && days_of_week.empty?
        return 'every month on the last day' if interval == 1
        return "every #{interval} months on the last day"
      end

      # "First Monday", "Last Friday", etc.
      days = days_of_week.map(&:capitalize).join(' and ')
      "every #{index} #{days}"
    end

    def map_absoluteYearly
      interval == 1 ? 'every year' : "every #{interval} years"
    end

    def map_relativeYearly
      map_absoluteYearly
    end

    def fallback_mapping
      "every #{interval} #{pattern['type'] || 'day'}"
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/recurrence_mapper_spec.rb`
Expected: All tests pass (15 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/export_ms_todo/recurrence_mapper.rb spec/export_ms_todo/recurrence_mapper_spec.rb
git commit -m "feat: add recurrence pattern mapper with comprehensive coverage"
```

---

## Task 5: MS Graph Client & Repository (TDD)

**Files:**
- Create: `spec/export_ms_todo/graph_client_spec.rb`
- Create: `lib/export_ms_todo/graph_client.rb`
- Create: `spec/export_ms_todo/task_repository_spec.rb`
- Create: `lib/export_ms_todo/task_repository.rb`
- Create: `spec/fixtures/vcr_cassettes/` (directory)

**Step 1: Write failing tests for GraphClient**

```ruby
# spec/export_ms_todo/graph_client_spec.rb
require 'spec_helper'
require 'export_ms_todo/graph_client'

RSpec.describe ExportMsTodo::GraphClient do
  let(:token) { 'Bearer test_token_123' }
  subject(:client) { described_class.new(token) }

  describe '#initialize' do
    it 'sets authorization header' do
      expect(client.instance_variable_get(:@token)).to eq(token)
    end

    it 'prepends Bearer if missing' do
      client_without_bearer = described_class.new('raw_token')
      expect(client_without_bearer.instance_variable_get(:@token)).to eq('Bearer raw_token')
    end
  end

  describe '#get', :vcr do
    it 'performs a GET request' do
      stub_request(:get, /graph.microsoft.com/)
        .to_return(status: 200, body: '{}')

      response = client.get('/me/todo/lists')
      expect(response.code).to eq(200)
    end

    describe 'error handling' do
      it 'raises AuthenticationError on 401' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 401)

        expect { client.get('/me') }.to raise_error(ExportMsTodo::AuthenticationError)
      end

      it 'raises RateLimitError on 429' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 429, headers: { 'Retry-After' => '60' })

        expect { client.get('/me') }.to raise_error(ExportMsTodo::RateLimitError)
      end

      it 'retries on 5xx errors' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 500).then
          .to_return(status: 200, body: '{}')

        expect { client.get('/me') }.not_to raise_error
      end
    end
  end
end
```

**Step 2: Write GraphClient implementation**

```ruby
# lib/export_ms_todo/graph_client.rb
require 'httparty'
require 'time'

module ExportMsTodo
  class GraphClient
    include HTTParty
    base_uri 'https://graph.microsoft.com/v1.0'

    MAX_RETRIES = 3

    def initialize(token)
      @token = token.start_with?('Bearer ') ? token : "Bearer #{token}"
      @headers = { 'Authorization' => @token }
    end

    def get(path)
      get_with_retry(path)
    end

    private

    def get_with_retry(path, retries = MAX_RETRIES)
      response = self.class.get(path, headers: @headers)

      case response.code
      when 200..299
        response
      when 401
        raise AuthenticationError, 'Invalid or expired token'
      when 429
        retry_after = parse_retry_after(response.headers['Retry-After'])
        raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds"
      when 500..599
        if retries > 0
          sleep(2 ** (MAX_RETRIES - retries))  # Exponential backoff
          get_with_retry(path, retries - 1)
        else
          raise Error, "Server error: #{response.code}"
        end
      else
        raise Error, "Unexpected response: #{response.code}"
      end
    end

    def parse_retry_after(header_val)
      return 60 if header_val.nil? || header_val.empty?

      if header_val.match?(/^\d+$/)
        header_val.to_i
      else
        # Handle HTTP Date format
        (Time.httpdate(header_val) - Time.now).to_i
      end
    rescue
      60 # Fallback default
    end
  end
end
```

**Step 3: Write failing tests for TaskRepository**

```ruby
# spec/export_ms_todo/task_repository_spec.rb
require 'spec_helper'
require 'export_ms_todo/task_repository'
require 'export_ms_todo/graph_client'

RSpec.describe ExportMsTodo::TaskRepository do
  let(:client) { instance_double(ExportMsTodo::GraphClient) }
  subject(:repo) { described_class.new(client) }

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
      allow(client).to receive(:get).with(/\/checklistItems$/).and_return(checklist_response)
    end

    it 'fetches lists and tasks' do
      result = repo.fetch_all_tasks
      expect(result).to be_an(Array)
      expect(result.first[:list]['displayName']).to eq('Work')
      expect(result.first[:tasks].first).to be_a(ExportMsTodo::Task)
    end
  end
end
```

**Step 4: Write TaskRepository implementation**

```ruby
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
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/export_ms_todo/graph_client_spec.rb spec/export_ms_todo/task_repository_spec.rb`

**Step 6: Commit**

```bash
git add lib/export_ms_todo/graph_client.rb lib/export_ms_todo/task_repository.rb spec/export_ms_todo/graph_client_spec.rb spec/export_ms_todo/task_repository_spec.rb
git commit -m "feat: add GraphClient and TaskRepository"
```

---

## Task 6: Todoist CSV Exporter (TDD)

**Files:**
- Create: `spec/export_ms_todo/exporters/todoist_csv_spec.rb`
- Create: `lib/export_ms_todo/exporters/todoist_csv.rb`

**Step 1: Write failing tests for CSV exporter**

```ruby
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
      expect(row['PRIORITY']).to eq('1')  # high importance
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

      expect(csv.size).to eq(3)  # 1 parent + 2 subtasks

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
      content = result.first[:content]

      # CSV should properly escape quotes
      expect(content).to include('Task with "quotes" inside')
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/exporters/todoist_csv_spec.rb`
Expected: LoadError - cannot load such file

**Step 3: Write TodoistCSV exporter implementation**

```ruby
# lib/export_ms_todo/exporters/todoist_csv.rb
require 'csv'
require_relative 'task_chunker'
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class TodoistCSV
      MAX_TASKS_PER_FILE = 300

      TODOIST_HEADERS = [
        'TYPE', 'CONTENT', 'DESCRIPTION', 'PRIORITY', 'INDENT',
        'AUTHOR', 'RESPONSIBLE', 'DATE', 'DATE_LANG', 'TIMEZONE'
      ].freeze

      def export(grouped_tasks)
        grouped_tasks.flat_map do |group|
          list = group[:list]
          tasks = group[:tasks]

          # KISS: Simple path for most lists (≤300 tasks)
          if total_task_count(tasks) <= MAX_TASKS_PER_FILE
            single_file_export(list, tasks)
          else
            # Complex path: delegate to specialist
            TaskChunker.new(list, tasks, self).export
          end
        end
      end

      def generate_csv(list, tasks)
        CSV.generate(headers: true, write_headers: true) do |csv|
          csv << TODOIST_HEADERS

          tasks.each do |task|
            add_task_rows(csv, task)
          end
        end
      end

      private

      def single_file_export(list, tasks)
        [{
          filename: Utils.sanitize_filename(list['displayName'], 'csv'),
          content: generate_csv(list, tasks)
        }]
      end

      def add_task_rows(csv, task)
        # Parent task
        csv << [
          'task',                          # TYPE
          task.title,                      # CONTENT
          task.body || '',                 # DESCRIPTION
          task.todoist_priority,           # PRIORITY
          1,                               # INDENT (parent)
          '',                              # AUTHOR
          '',                              # RESPONSIBLE
          task.due_date || '',             # DATE
          'en',                            # DATE_LANG
          task.due_timezone || ''          # TIMEZONE
        ]

        # Subtasks (checklist items)
        task.checklist_items.each do |item|
          csv << [
            'task',                        # TYPE
            item['displayName'],           # CONTENT
            '',                            # DESCRIPTION
            task.todoist_priority,         # PRIORITY (inherit from parent)
            2,                             # INDENT (subtask)
            '',                            # AUTHOR
            '',                            # RESPONSIBLE
            '',                            # DATE
            'en',                          # DATE_LANG
            ''                             # TIMEZONE
          ]
        end
      end

      def total_task_count(tasks)
        tasks.sum(&:total_task_count)
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/exporters/todoist_csv_spec.rb`
Expected: Some tests pass, TaskChunker tests fail (not implemented yet)

**Step 5: Commit what we have**

```bash
git add lib/export_ms_todo/exporters/todoist_csv.rb spec/export_ms_todo/exporters/todoist_csv_spec.rb
git commit -m "feat: add Todoist CSV exporter with proper escaping"
```

---

## Task 7: Task Chunker (TDD)

**Files:**
- Create: `spec/export_ms_todo/exporters/task_chunker_spec.rb`
- Create: `lib/export_ms_todo/exporters/task_chunker.rb`

**Step 1: Write failing tests for TaskChunker**

```ruby
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
      complex_task = build_task('Complex', 50)  # 1 + 50 = 51 rows

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
      expect(result.size).to eq(1)  # One chunk with 351 rows
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/exporters/task_chunker_spec.rb`
Expected: LoadError - cannot load such file

**Step 3: Write TaskChunker implementation**

```ruby
# lib/export_ms_todo/exporters/task_chunker.rb
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class TaskChunker
      MAX_SIZE = 300

      def initialize(list, tasks, exporter)
        @list = list
        @tasks = tasks
        @exporter = exporter
      end

      def export
        chunks = split_tasks_into_chunks

        chunks.map.with_index do |chunk, index|
          {
            filename: Utils.sanitize_filename(@list['displayName'], 'csv').sub('.csv', "-#{index + 1}.csv"),
            content: @exporter.generate_csv(@list, chunk),
            part: index + 1,
            total_parts: chunks.size
          }
        end
      end

      private

      def split_tasks_into_chunks
        chunks = []
        current_chunk = []
        current_count = 0

        @tasks.each do |task|
          task_size = task.total_task_count

          # Edge case: single task exceeds limit
          if task_size > MAX_SIZE
            warn "⚠️  Task '#{task.title}' has #{task.subtask_count} subtasks (exceeds 300 limit)"

            # Flush current chunk if not empty
            chunks << current_chunk if current_chunk.any?

            # Put oversized task in its own chunk
            chunks << [task]

            # Reset for next chunk
            current_chunk = []
            current_count = 0
            next
          end

          # Start new chunk if adding this task would exceed limit
          if current_count + task_size > MAX_SIZE && current_chunk.any?
            chunks << current_chunk
            current_chunk = []
            current_count = 0
          end

          current_chunk << task
          current_count += task_size
        end

        # Don't forget the last chunk
        chunks << current_chunk if current_chunk.any?

        chunks
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/exporters/task_chunker_spec.rb`
Expected: All tests pass

**Step 5: Verify TodoistCSV tests now pass**

Run: `bundle exec rspec spec/export_ms_todo/exporters/todoist_csv_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/export_ms_todo/exporters/task_chunker.rb spec/export_ms_todo/exporters/task_chunker_spec.rb
git commit -m "feat: add TaskChunker to handle large lists (>300 tasks)"
```

---

## Task 8: JSON Exporter (TDD)

**Files:**
- Create: `spec/export_ms_todo/exporters/json_spec.rb`
- Create: `lib/export_ms_todo/exporters/json.rb`

**Step 1: Write failing tests for JSON exporter**

```ruby
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/exporters/json_spec.rb`
Expected: LoadError

**Step 3: Write JSON exporter implementation**

```ruby
# lib/export_ms_todo/exporters/json.rb
require 'json'
require_relative '../utils'

module ExportMsTodo
  module Exporters
    class JSON
      def export(grouped_tasks)
        grouped_tasks.map do |group|
          list = group[:list]
          tasks = group[:tasks]

          {
            filename: Utils.sanitize_filename(list['displayName'], 'json'),
            content: generate_json(list, tasks)
          }
        end
      end

      private

      def generate_json(list, tasks)
        data = {
          list: {
            id: list['id'],
            displayName: list['displayName']
          },
          tasks: tasks.map { |task| task_to_hash(task) },
          task_count: tasks.size,
          exported_at: Time.now.iso8601
        }

        ::JSON.pretty_generate(data)
      end

      def task_to_hash(task)
        {
          id: task.id,
          title: task.title,
          body: task.body,
          importance: task.importance,
          status: task.status,
          due_date: task.due_date,
          due_timezone: task.due_timezone,
          recurrence: task.recurrence,
          checklist_items: task.checklist_items,
          list_name: task.list_name,
          list_id: task.list_id,
          created_at: task.created_at,
          updated_at: task.updated_at,
          todoist_priority: task.todoist_priority,
          subtask_count: task.subtask_count
        }
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/exporters/json_spec.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/export_ms_todo/exporters/json.rb spec/export_ms_todo/exporters/json_spec.rb
git commit -m "feat: add JSON exporter for debugging"
```

---

## Task 9: Configuration System (TDD)

**Files:**
- Create: `spec/export_ms_todo/config_spec.rb`
- Create: `lib/export_ms_todo/config.rb`
- Create: `config/default.yml`

**Step 1: Write failing tests for Config**

```ruby
# spec/export_ms_todo/config_spec.rb
require 'spec_helper'
require 'export_ms_todo/config'

RSpec.describe ExportMsTodo::Config do
  subject(:config) { described_class.new }

  describe 'default values' do
    it 'sets sensible defaults' do
      expect(config.output_format).to eq('csv')
      expect(config.single_file).to eq(false)
      expect(config.output_path).to eq('./ms-todo-export')
      expect(config.include_completed).to eq(false)
    end
  end

  describe 'loading from file' do
    let(:config_file) { 'spec/fixtures/test_config.yml' }

    before do
      File.write(config_file, <<~YAML)
        output:
          format: json
          single_file: true
          path: /tmp/export
        csv:
          include_completed: true
      YAML
    end

    after do
      File.delete(config_file) if File.exist?(config_file)
    end

    it 'loads configuration from YAML file' do
      config = described_class.new(config_file: config_file)

      expect(config.output_format).to eq('json')
      expect(config.single_file).to eq(true)
      expect(config.output_path).to eq('/tmp/export')
      expect(config.include_completed).to eq(true)
    end
  end

  describe 'environment variables' do
    around do |example|
      original_env = ENV.to_h
      ENV['MS_TODO_OUTPUT_PATH'] = '/custom/path'
      ENV['MS_TODO_FORMAT'] = 'json'

      example.run

      ENV.replace(original_env)
    end

    it 'reads from environment variables' do
      config = described_class.new

      expect(config.output_path).to eq('/custom/path')
      expect(config.output_format).to eq('json')
    end
  end

  describe 'priority order' do
    let(:config_file) { 'spec/fixtures/test_config.yml' }

    before do
      File.write(config_file, <<~YAML)
        output:
          format: csv
          path: /from/file
      YAML

      ENV['MS_TODO_OUTPUT_PATH'] = '/from/env'
    end

    after do
      File.delete(config_file) if File.exist?(config_file)
      ENV.delete('MS_TODO_OUTPUT_PATH')
    end

    it 'prioritizes manual overrides > env vars > config file > defaults' do
      config = described_class.new(
        config_file: config_file,
        overrides: { output_path: '/from/override' }
      )

      # Override wins
      expect(config.output_path).to eq('/from/override')
    end

    it 'falls back to env vars when no override' do
      config = described_class.new(config_file: config_file)

      # Env var wins over config file
      expect(config.output_path).to eq('/from/env')
    end
  end

  describe 'token handling' do
    it 'reads token from env var' do
      ENV['MS_TODO_TOKEN'] = 'Bearer test123'

      config = described_class.new
      expect(config.token).to eq('Bearer test123')

      ENV.delete('MS_TODO_TOKEN')
    end

    it 'accepts token as override' do
      config = described_class.new(overrides: { token: 'Bearer override' })
      expect(config.token).to eq('Bearer override')
    end

    it 'returns nil if no token found' do
      ENV.delete('MS_TODO_TOKEN')
      config = described_class.new
      expect(config.token).to be_nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/export_ms_todo/config_spec.rb`
Expected: LoadError

**Step 3: Create config/default.yml**

```yaml
# config/default.yml
output:
  format: csv              # csv or json
  single_file: false       # One CSV per list (in ZIP)
  path: "./ms-todo-export" # Output path

unmappable_data:
  reminders: skip          # skip | append_to_description (v2)
  attachments: skip        # skip | append_to_description (v2)

api:
  pagination_limit: 100
  timeout: 30

csv:
  include_completed: false
  priority_mapping:
    low: 4
    normal: 4
    high: 1
```

**Step 4: Write Config implementation**

```ruby
# lib/export_ms_todo/config.rb
require 'yaml'

module ExportMsTodo
  class Config
    attr_reader :output_format, :single_file, :output_path,
                :include_completed, :token,
                :pagination_limit, :timeout

    DEFAULT_CONFIG_PATH = File.expand_path('../../config/default.yml', __dir__)
    USER_CONFIG_PATHS = [
      File.expand_path('~/.export-ms-todo.yml'),
      './config.yml'
    ].freeze

    def initialize(config_file: nil, overrides: {})
      @defaults = load_yaml(DEFAULT_CONFIG_PATH)
      @file_config = load_file_config(config_file)
      @env_config = load_env_config
      @overrides = overrides

      merge_configs!
    end

    private

    def load_yaml(path)
      return {} unless File.exist?(path)
      YAML.load_file(path) || {}
    rescue => e
      warn "Failed to load config from #{path}: #{e.message}"
      {}
    end

    def load_file_config(explicit_path)
      if explicit_path
        load_yaml(explicit_path)
      else
        # Try user config paths
        USER_CONFIG_PATHS.each do |path|
          config = load_yaml(path)
          return config if config.any?
        end
        {}
      end
    end

    def load_env_config
      {
        'output' => {
          'format' => ENV['MS_TODO_FORMAT'],
          'path' => ENV['MS_TODO_OUTPUT_PATH'],
          'single_file' => ENV['MS_TODO_SINGLE_FILE'] == 'true'
        }.compact,
        'token' => ENV['MS_TODO_TOKEN']
      }.compact
    end

    def merge_configs!
      # Priority: overrides > env > file > defaults
      config = deep_merge(@defaults, @file_config)
      config = deep_merge(config, @env_config)
      config = deep_merge(config, @overrides)

      # Set instance variables
      @output_format = config.dig('output', 'format') || 'csv'
      @single_file = config.dig('output', 'single_file') || false
      @output_path = config.dig('output', 'path') || './ms-todo-export'
      @include_completed = config.dig('csv', 'include_completed') || false
      @pagination_limit = config.dig('api', 'pagination_limit') || 100
      @timeout = config.dig('api', 'timeout') || 30
      @token = config['token']
    end

    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val.nil? ? old_val : new_val
        end
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/export_ms_todo/config_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/export_ms_todo/config.rb spec/export_ms_todo/config_spec.rb config/default.yml
git commit -m "feat: add hybrid configuration system"
```

---

## Task 10: CLI with Thor (TDD)

**Files:**
- Create: `spec/cli_spec.rb`
- Create: `bin/export-ms-todo`

**Step 1: Write failing tests for CLI**

```ruby
# spec/cli_spec.rb
require 'spec_helper'
require 'thor'

# Load the CLI
load File.expand_path('../bin/export-ms-todo', __dir__)

RSpec.describe ExportMsTodo::CLI do
  let(:token) { 'Bearer test_token' }

  before do
    ENV['MS_TODO_TOKEN'] = token
  end

  after do
    ENV.delete('MS_TODO_TOKEN')
    Dir.glob('*.{zip,csv,json}').each { |f| File.delete(f) }
  end

  describe 'export command' do
    it 'runs with default options' do
      output = capture_stdout do
        described_class.start(['export'])
      end

      expect(output).to include('Export complete')
    end

    it 'accepts --output flag' do
      described_class.start(['export', '--output=test-export'])

      # Should create test-export.zip (or .csv/.json depending on format)
      expect(Dir.glob('test-export*')).not_to be_empty
    end

    it 'accepts --format flag' do
      described_class.start(['export', '--format=json', '--output=test'])

      # Should create JSON files
      files = Dir.glob('test*')
      expect(files.any? { |f| f.end_with?('.json') || f.end_with?('.zip') }).to be true
    end

    it 'accepts --single-file flag' do
      output = capture_stdout do
        described_class.start(['export', '--single-file', '--output=single.csv'])
      end

      expect(File.exist?('single.csv')).to be true
    end

    it 'prompts for token if not in env' do
      ENV.delete('MS_TODO_TOKEN')

      # Mock Thor shell interaction
      allow_any_instance_of(Thor::Shell::Basic).to receive(:ask).and_return("Bearer prompted_token")

      output = capture_stdout do
        described_class.start(['export'])
      end

      # We might not see the prompt in stdout capture depending on how Thor handles it,
      # but the execution should succeed with the mocked token
      expect(output).to include('Export complete')
    end
  end

  describe 'version command' do
    it 'displays version' do
      output = capture_stdout do
        described_class.start(['version'])
      end

      expect(output).to include(ExportMsTodo::VERSION)
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: LoadError

**Step 3: Write CLI implementation**

```ruby
#!/usr/bin/env ruby
# bin/export-ms-todo

require 'bundler/setup'
require 'thor'
require 'dotenv/load'
require 'zip'
require_relative '../lib/export_ms_todo'
require_relative '../lib/export_ms_todo/graph_client'
require_relative '../lib/export_ms_todo/task_repository'
require_relative '../lib/export_ms_todo/config'
require_relative '../lib/export_ms_todo/exporters/todoist_csv'
require_relative '../lib/export_ms_todo/exporters/json'

module ExportMsTodo
  class CLI < Thor
    include Thor::Actions

    def self.exit_on_failure?
      true
    end

    desc 'export', 'Export MS Todo tasks to Todoist CSV format'
    option :output, aliases: '-o', desc: 'Output path (default: ./ms-todo-export)'
    option :format, aliases: '-f', enum: ['csv', 'json'], default: 'csv', desc: 'Output format'
    option :single_file, type: :boolean, default: false, desc: 'Export all lists to single file'
    option :token, aliases: '-t', desc: 'MS Graph access token'
    def export
      trap('SIGINT') do
        say "\n\n❌ Export cancelled by user.", :red
        exit 130
      end

      say "╭─────────────────────────────────────────╮", :blue
      say "│  Export MS Todo → Todoist              │", :blue
      say "╰─────────────────────────────────────────╯", :blue
      say

      # Get configuration
      config = Config.new(overrides: {
        output_path: options[:output],
        output_format: options[:format],
        single_file: options[:single_file],
        token: options[:token]
      })

      token = config.token || prompt_for_token
      
      client = GraphClient.new(token)
      repo = TaskRepository.new(client)

      say "✓ Authenticated successfully", :green
      say "✓ Fetching tasks...", :green

      # Fetch tasks
      grouped_tasks = repo.fetch_all_tasks

      if grouped_tasks.empty?
        say "No lists found.", :yellow
        exit 0
      end

      # Display summary
      grouped_tasks.each do |group|
        list_name = group[:list]['displayName']
        task_count = group[:tasks].sum(&:total_task_count)
        say "  → #{list_name}: #{task_count} tasks"
      end

      say "\nGenerating #{config.output_format.upcase} files...", :green

      # Export
      exporter = config.output_format == 'json' ?
        Exporters::JSON.new : Exporters::TodoistCSV.new

      files = exporter.export(grouped_tasks)

      # Write files
      if config.single_file || files.size == 1
        # Single file output
        file = files.first
        output_path = config.output_path
        output_path += ".#{config.output_format}" unless output_path.end_with?(".#{config.output_format}")

        create_file(output_path, file[:content])
      else
        # Multiple files - create ZIP
        output_path = config.output_path
        output_path += '.zip' unless output_path.end_with?('.zip')

        create_file(output_path) do # Thor's create_file
           create_zip_content(files)
        end
      end

      say "\nExport complete!", :green
      say "📦 #{File.basename(output_path)}"

      # Show chunked file warnings
      chunked_lists = files.select { |f| f[:total_parts] && f[:total_parts] > 1 }
                           .group_by { |f| f[:filename].gsub(/-\d+\.csv$/, '') }

      if chunked_lists.any?
        say "\n⚠️  Note: Some lists were split due to 300-task limit:", :yellow
        chunked_lists.each do |base_name, parts|
          say "   - #{base_name}: Import #{parts.size} files to same project"
        end
      end

      say "\nNext steps:"
      say "1. Go to Todoist → Settings → Import"
      say "2. Upload CSV files (numbered files to same project)"
    rescue AuthenticationError => e
      say "\n✗ Authentication failed", :red
      say "  #{e.message}"
      say "  Get a new token: https://developer.microsoft.com/en-us/graph/graph-explorer"
      exit 1
    rescue RateLimitError => e
      say "\n✗ Rate limit exceeded", :red
      say "  #{e.message}"
      exit 1
    rescue => e
      say "\n✗ Error: #{e.message}", :red
      say e.backtrace.first(5).join("\n") if ENV['DEBUG']
      exit 1
    end

    desc 'version', 'Display version'
    def version
      say "export-ms-todo v#{VERSION}"
    end

    private

    def prompt_for_token
      say "No token found. Please enter your MS Graph access token:"
      say "(Get it from: https://developer.microsoft.com/en-us/graph/graph-explorer)"
      say

      token = ask("Token:", :echo => false)
      say "" # Newline after silent input

      token.empty? ? (raise Error, "Token required") : token
    end

    def create_zip_content(files)
      Zip::OutputStream.write_buffer do |zip|
        files.each do |file|
          zip.put_next_entry(file[:filename])
          zip.write file[:content]
        end
      end.string
    end
  end
end

# Run CLI if executed directly
ExportMsTodo::CLI.start(ARGV) if __FILE__ == $PROGRAM_NAME
```



**Step 4: Make executable**

Run: `chmod +x bin/export-ms-todo`

**Step 5: Test manually**

Run: `bin/export-ms-todo help`
Expected: Help output displayed

**Step 6: Run automated tests**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: Tests pass (may need VCR cassettes or mocks)

**Step 7: Commit**

```bash
git add bin/export-ms-todo spec/cli_spec.rb
git commit -m "feat: add Thor CLI with interactive prompts"
```

---

## Task 11: Sinatra API

**Files:**
- Create: `spec/api_spec.rb`
- Create: `api/app.rb`
- Create: `api/config.ru`

**Step 1: Write failing tests for API**

```ruby
# spec/api_spec.rb
require 'spec_helper'
require 'rack/test'
require_relative '../api/app'

RSpec.describe 'ExportMsTodo API' do
  include Rack::Test::Methods

  def app
    ExportMsTodo::API
  end

  let(:valid_token) { 'Bearer test_token_123' }

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'

      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)).to eq({
        'status' => 'ok',
        'version' => ExportMsTodo::VERSION
      })
    end
  end

  describe 'GET /lists' do
    it 'requires token parameter' do
      get '/lists'

      expect(last_response.status).to eq(400)
    end

    it 'returns list of MS Todo lists', :vcr do
      get '/lists', token: valid_token

      expect(last_response).to be_ok

      data = JSON.parse(last_response.body)
      expect(data).to have_key('lists')
      expect(data['lists']).to be_an(Array)
    end

    it 'handles authentication errors' do
      get '/lists', token: 'invalid_token'

      expect(last_response.status).to eq(401)
    end
  end

  describe 'POST /export' do
    it 'requires token parameter' do
      post '/export'

      expect(last_response.status).to eq(400)
    end

    it 'exports to ZIP by default', :vcr do
      post '/export', token: valid_token

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to eq('application/zip')
      expect(last_response.headers['Content-Disposition']).to include('attachment')
      expect(last_response.headers['Content-Disposition']).to include('.zip')
    end

    it 'exports to single CSV with single_file=true', :vcr do
      post '/export', token: valid_token, single_file: true

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to eq('text/csv')
    end

    it 'exports to JSON format', :vcr do
      post '/export', token: valid_token, format: 'json'

      expect(last_response).to be_ok
      expect(last_response.headers['Content-Type']).to include('application/json')
    end

    it 'handles invalid format' do
      post '/export', token: valid_token, format: 'invalid'

      expect(last_response.status).to eq(400)
    end

    it 'handles authentication errors' do
      post '/export', token: 'invalid'

      expect(last_response.status).to eq(401)
    end

    it 'handles rate limit errors' do
      # Mock rate limit response
      allow_any_instance_of(ExportMsTodo::Client)
        .to receive(:fetch_all_tasks)
        .and_raise(ExportMsTodo::RateLimitError.new('Rate limited'))

      post '/export', token: valid_token

      expect(last_response.status).to eq(429)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/api_spec.rb`
Expected: LoadError

**Step 3: Write API implementation**

```ruby
# api/app.rb
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'
require 'sinatra/base'
require 'json'
require 'zip'
require_relative '../lib/export_ms_todo'
require_relative '../lib/export_ms_todo/graph_client'
require_relative '../lib/export_ms_todo/task_repository'
require_relative '../lib/export_ms_todo/exporters/todoist_csv'
require_relative '../lib/export_ms_todo/exporters/json'

module ExportMsTodo
  class API < Sinatra::Base
    configure do
      set :show_exceptions, false
      set :raise_errors, false
    end

    # Health check
    get '/health' do
      content_type :json
      { status: 'ok', version: VERSION }.to_json
    end

    # Get lists (preview)
    get '/lists' do
      token = params[:token]
      halt 400, { error: 'Token required' }.to_json unless token

      client = GraphClient.new(token)
      repo = TaskRepository.new(client)
      lists = repo.fetch_lists

      content_type :json
      {
        lists: lists.map { |l| { id: l['id'], name: l['displayName'] } }
      }.to_json
    rescue AuthenticationError => e
      halt 401, { error: e.message }.to_json
    rescue RateLimitError => e
      halt 429, { error: e.message }.to_json
    rescue => e
      halt 500, { error: e.message }.to_json
    end

    # Export tasks
    post '/export' do
      token = params[:token]
      halt 400, { error: 'Token required' }.to_json unless token

      format = params[:format] || 'csv'
      halt 400, { error: 'Invalid format' }.to_json unless ['csv', 'json'].include?(format)

      single_file = params[:single_file] == 'true' || params[:single_file] == true

      # Fetch tasks
      client = GraphClient.new(token)
      repo = TaskRepository.new(client)
      grouped_tasks = repo.fetch_all_tasks

      # Export
      exporter = format == 'json' ?
        Exporters::JSON.new : Exporters::TodoistCSV.new

      files = exporter.export(grouped_tasks)

      # Return response
      if single_file || files.size == 1
        file = files.first
        content_type format == 'json' ? 'application/json' : 'text/csv'
        attachment file[:filename]
        file[:content]
      else
        # Create ZIP
        zip_content = create_zip(files)

        content_type 'application/zip'
        attachment 'ms-todo-export.zip'
        zip_content
      end
    rescue AuthenticationError => e
      halt 401, { error: e.message }.to_json
    rescue RateLimitError => e
      halt 429, { error: e.message }.to_json
    rescue => e
      halt 500, { error: e.message }.to_json
    end

    private

    def create_zip(files)
      zip_stream = Zip::OutputStream.write_buffer do |zip|
        files.each do |file|
          zip.put_next_entry(file[:filename])
          zip.write file[:content]
        end
      end

      zip_stream.rewind
      zip_stream.read
    end
  end
end
```

**Step 4: Create config.ru**

```ruby
# api/config.ru
require_relative 'app'

run ExportMsTodo::API
```

**Step 5: Run tests**

Run: `bundle exec rspec spec/api_spec.rb`
Expected: Tests pass (with VCR or mocks)

**Step 6: Test API manually**

Run: `bundle exec rackup api/config.ru -p 3000`

In another terminal:
```bash
curl http://localhost:3000/health
# Expected: {"status":"ok","version":"0.1.0"}
```

**Step 7: Commit**

```bash
git add api/app.rb api/config.ru spec/api_spec.rb
git commit -m "feat: add Sinatra API with export endpoints"
```

---

## Task 12: Integration with Recurrence Mapper

**Files:**
- Modify: `lib/export_ms_todo/exporters/todoist_csv.rb`
- Modify: `spec/export_ms_todo/exporters/todoist_csv_spec.rb`

**Step 1: Add test for recurrence in CSV export**

```ruby
# Add to spec/export_ms_todo/exporters/todoist_csv_spec.rb

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
        'daysOfWeek' => ['monday', 'wednesday']
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
```

**Step 2: Update TodoistCSV to use RecurrenceMapper**

```ruby
# In lib/export_ms_todo/exporters/todoist_csv.rb

require_relative '../recurrence_mapper'

# Update add_task_rows method:

def add_task_rows(csv, task)
  # Determine DATE field
  date_value = if task.recurrence
    RecurrenceMapper.new.map(task.recurrence)
  else
    task.due_date || ''
  end

  # Parent task
  csv << [
    'task',
    task.title,
    task.body || '',
    task.todoist_priority,
    1,
    '',
    '',
    date_value,
    'en',
    task.due_timezone || ''
  ]

  # Subtasks...
end
```

**Step 3: Run tests**

Run: `bundle exec rspec spec/export_ms_todo/exporters/todoist_csv_spec.rb`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/export_ms_todo/exporters/todoist_csv.rb spec/export_ms_todo/exporters/todoist_csv_spec.rb
git commit -m "feat: integrate recurrence mapper into CSV export"
```

---

## Task 13: Documentation & Final Polish

**Files:**
- Modify: `README.md`
- Create: `LICENSE`
- Create: `CHANGELOG.md`

**Step 1: Update README with comprehensive documentation**

```markdown
# Export MS Todo

Export Microsoft To Do tasks to Todoist CSV format.

## Features

- ✅ Export all tasks with titles, descriptions, priorities, due dates
- ✅ Convert checklist items to subtasks
- ✅ Map recurrence patterns (daily, weekly, monthly, yearly)
- ✅ Handle large lists (>300 tasks) with automatic splitting
- ✅ Both CLI and API interfaces
- ✅ Zero-config with sensible defaults
- ✅ JSON export for debugging

## Quick Start

### Installation

```bash
git clone https://github.com/yourusername/export-ms-todo.git
cd export-ms-todo
bundle install
```

### Get Your Token

1. Go to [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in with your Microsoft account
3. Select "my To Do task lists"
4. Click "Modify permissions" → consent to "Tasks.ReadWrite"
5. Copy the access token from "Access token" tab

### CLI Usage

```bash
# Set up token (one time)
cp .env.example .env
# Edit .env and paste your token

# Export (creates ms-todo-export.zip)
bundle exec bin/export-ms-todo export

# Custom output path
bundle exec bin/export-ms-todo export --output ~/Desktop/tasks

# Single CSV file
bundle exec bin/export-ms-todo export --single-file

# JSON format (debugging)
bundle exec bin/export-ms-todo export --format json
```

### API Usage

```bash
# Start server
bundle exec rackup api/config.ru -p 3000

# Export via API
curl -X POST http://localhost:3000/export \
  -d "token=Bearer YOUR_TOKEN" \
  --output export.zip

# Get lists (preview)
curl "http://localhost:3000/lists?token=Bearer YOUR_TOKEN"

# Health check
curl http://localhost:3000/health
```

## Importing to Todoist

1. Go to Todoist → Settings → Import
2. Upload each CSV file
3. For split lists (Work-1.csv, Work-2.csv), import both to the same project

## Configuration

### Environment Variables

```bash
MS_TODO_TOKEN=Bearer your_token_here
MS_TODO_OUTPUT_PATH=./custom-path
MS_TODO_FORMAT=csv  # or json
MS_TODO_SINGLE_FILE=false
```

### Config File

Create `~/.export-ms-todo.yml`:

```yaml
output:
  format: csv
  single_file: false
  path: "./exports"

csv:
  include_completed: false
```

## Field Mapping

| MS Todo | Todoist CSV |
|---------|-------------|
| Title | CONTENT |
| Body | DESCRIPTION |
| High importance | PRIORITY 1 |
| Normal/Low importance | PRIORITY 4 |
| Checklist items | Subtasks (INDENT=2) |
| Due date | DATE |
| Timezone | TIMEZONE |
| Recurrence | DATE (natural language) |

### Recurrence Examples

- Daily → `every day`
- Every 3 months → `every 3 months`
- Every Monday and Friday → `every Monday and Friday`
- Last day of month → `every month on the last day`

## Development

```bash
# Run tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/export_ms_todo/recurrence_mapper_spec.rb

# Record VCR cassettes (with real token)
export MS_TODO_TOKEN="Bearer real_token"
bundle exec rspec --tag vcr
```

## License

GPL v3.0 (matching source Java project)

## Credits

Inspired by [Microsoft-To-Do-Export](https://github.com/daylamtayari/Microsoft-To-Do-Export) by Daylam Tayari.
```

**Step 2: Create LICENSE**

```
# Copy GPL v3.0 license
wget https://www.gnu.org/licenses/gpl-3.0.txt -O LICENSE
```

**Step 3: Create CHANGELOG.md**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-12-29

### Added
- Initial release
- CLI interface with Thor
- API interface with Sinatra
- MS Graph API client with retry logic
- Todoist CSV exporter with proper escaping
- JSON exporter for debugging
- Recurrence pattern mapper (20+ patterns)
- TaskChunker for large lists (>300 tasks)
- Hybrid configuration system
- Comprehensive test suite (90%+ coverage)

### Supported Features
- Task title, body, priority, due dates
- Checklist items → subtasks
- Recurrence patterns (daily, weekly, monthly, yearly)
- Large list handling with automatic splitting
- Zero-config with .env support
```

**Step 4: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 5: Manual end-to-end test**

```bash
# Set real token
export MS_TODO_TOKEN="Bearer real_token"

# Run export
bundle exec bin/export-ms-todo export --output test-export

# Verify ZIP created
ls -lh test-export.zip

# Extract and check CSV
unzip test-export.zip
head -20 *.csv
```

**Step 6: Commit**

```bash
git add README.md LICENSE CHANGELOG.md
git commit -m "docs: add comprehensive documentation and license"
```

---

## Task 14: Final Verification & Release

**Step 1: Run full test suite**

Run: `bundle exec rspec --format documentation`
Expected: All tests pass with detailed output

**Step 2: Check test coverage**

Add to Gemfile (if not already there):
```ruby
gem 'simplecov', require: false, group: :test
```

Add to spec/spec_helper.rb (top):
```ruby
require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end
```

Run: `bundle exec rspec`
Open: `coverage/index.html`
Expected: >90% coverage

**Step 3: Verify CLI works end-to-end**

```bash
bundle exec bin/export-ms-todo export --format json --output test.json
cat test.json | jq '.lists[0].tasks[0]'
```

**Step 4: Verify API works end-to-end**

```bash
# Terminal 1
bundle exec rackup api/config.ru -p 3000

# Terminal 2
curl http://localhost:3000/health
curl -X POST http://localhost:3000/export -d "token=Bearer $MS_TODO_TOKEN" --output final-test.zip
unzip -l final-test.zip
```

**Step 5: Tag release**

```bash
git tag -a v0.1.0 -m "Initial release"
git push origin v0.1.0
```

**Step 6: Celebrate! 🎉**

You've built a comprehensive MS Todo → Todoist export tool with:
- ✅ Ruby with SOLID, DRY, KISS principles
- ✅ Thor CLI and Sinatra API
- ✅ Comprehensive field mapping
- ✅ Recurrence pattern support
- ✅ Large list handling (>300 tasks)
- ✅ 90%+ test coverage
- ✅ Zero-config UX

---

# Summary

This plan implements `export-ms-todo` in 14 bite-sized tasks:

1. Project setup (Gemfile, structure)
2. Core directory structure
3. Task model (TDD)
4. Recurrence mapper (TDD, 20+ test cases)
5. MS Graph API client (TDD, with retry logic)
6. Todoist CSV exporter (TDD, with escaping)
7. TaskChunker (TDD, KISS principle)
8. JSON exporter (TDD)
9. Configuration system (TDD, hybrid approach)
10. Thor CLI (interactive, zero-config)
11. Sinatra API (RESTful endpoints)
12. Integration (recurrence in CSV)
13. Documentation & polish
14. Final verification & release

**Each task follows TDD**: write test → run (fails) → implement → run (passes) → commit

**Time estimate**: ~8-12 hours total (30-60 min per task)
