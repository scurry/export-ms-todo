# Developer Guide

Guide for developers who want to contribute to or understand Export MS Todo.

## Table of Contents

- [Architecture](#architecture)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Core Components](#core-components)
- [Testing](#testing)
- [Code Style](#code-style)
- [Contribution Workflow](#contribution-workflow)
- [Release Process](#release-process)

---

## Architecture

### Design Principles

Export MS Todo follows these core principles:

- **KISS** - Simple path for common cases, complexity only when needed
- **DRY** - Shared business logic between CLI and API
- **SOLID** - Single responsibility, dependency injection, extensible design
- **TDD** - Test-driven development with comprehensive coverage

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interfaces                      │
│  ┌──────────────┐              ┌──────────────┐        │
│  │ CLI (Thor)   │              │ API (Sinatra)│        │
│  └──────┬───────┘              └──────┬───────┘        │
└─────────┼──────────────────────────────┼───────────────┘
          │                              │
          └───────────┬──────────────────┘
                      │
          ┌───────────▼───────────────────────┐
          │     Business Logic Layer          │
          │  ┌────────────┬─────────────┐     │
          │  │TaskRepo    │ Exporters   │     │
          │  │            │ - CSV       │     │
          │  │            │ - JSON      │     │
          │  └─────┬──────┴─────────────┘     │
          └────────┼────────────────────────────┘
                   │
          ┌────────▼─────────────────────┐
          │    Data Access Layer         │
          │  ┌──────────────────────┐    │
          │  │ GraphClient          │    │
          │  │ (MS Graph API)       │    │
          │  └──────────────────────┘    │
          └──────────────────────────────┘
```

### Component Separation

**GraphClient (HTTP/Auth)**
- Raw HTTP communication
- Authentication headers
- Rate limiting (429)
- Retries (5xx)

**TaskRepository (Business Logic)**
- Orchestrates data fetching
- Calls GraphClient for HTTP
- Enriches tasks with checklist items
- Returns structured data

**Exporters**
- `TodoistCSV` - CSV generation with escaping
- `TaskChunker` - Handles >300 task lists (KISS principle)
- `JSON` - Debug export format

---

## Development Setup

### Prerequisites

- **Ruby 3.2+**
  ```bash
  ruby --version
  # ruby 3.2.0 or higher
  ```

- **Bundler**
  ```bash
  gem install bundler
  ```

- **MS Graph Token** (for testing)
  - Get from: https://developer.microsoft.com/en-us/graph/graph-explorer
  - Consent to `Tasks.ReadWrite`

### Initial Setup

```bash
# Clone repository
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo

# Install dependencies
bundle install

# Set up environment
cp .env.example .env
# Edit .env and add your token

# Run tests
bundle exec rspec

# Try the CLI
bundle exec bin/export-ms-todo version
```

### Development Workflow with Worktrees

For feature development, use git worktrees for isolation:

```bash
# Create worktree
git worktree add .worktrees/my-feature -b feature/my-feature

# Work in isolation
cd .worktrees/my-feature
bundle install
bundle exec rspec

# When done
git worktree remove .worktrees/my-feature
```

---

## Project Structure

```
export-ms-todo/
├── lib/export_ms_todo/
│   ├── graph_client.rb        # MS Graph HTTP client
│   ├── task_repository.rb     # Data fetching orchestration
│   ├── task.rb                # Task model
│   ├── config.rb              # Configuration management
│   ├── recurrence_mapper.rb   # Recurrence pattern conversion
│   ├── utils.rb               # Shared utilities
│   ├── exporters/
│   │   ├── todoist_csv.rb     # CSV generation
│   │   ├── task_chunker.rb    # Large list handling
│   │   └── json.rb            # JSON export
│   └── version.rb
├── bin/
│   └── export-ms-todo         # CLI entry point (Thor)
├── api/
│   ├── app.rb                 # Sinatra API
│   └── config.ru              # Rack configuration
├── config/
│   ├── default.yml            # Default settings
│   └── puma.rb                # API server config
├── spec/                      # RSpec tests
│   ├── export_ms_todo/
│   │   ├── task_spec.rb
│   │   ├── graph_client_spec.rb
│   │   ├── task_repository_spec.rb
│   │   ├── recurrence_mapper_spec.rb
│   │   └── exporters/
│   │       ├── todoist_csv_spec.rb
│   │       ├── task_chunker_spec.rb
│   │       └── json_spec.rb
│   ├── cli_spec.rb
│   ├── api_spec.rb
│   ├── spec_helper.rb
│   └── fixtures/
│       └── vcr_cassettes/     # Recorded HTTP interactions
├── docs/
│   ├── QUICK_START.md
│   ├── USER_GUIDE.md
│   ├── DEVELOPER_GUIDE.md     # This file
│   ├── CONTRIBUTING.md
│   └── plans/                 # Design docs
├── .env.example               # Token template
├── Gemfile                    # Ruby dependencies
└── README.md
```

---

## Core Components

### Task Model

**File:** `lib/export_ms_todo/task.rb`

Rich domain object capturing MS Todo task data:

```ruby
class ExportMsTodo::Task
  attr_reader :id, :title, :body, :importance, :status,
              :due_date, :due_timezone, :recurrence,
              :checklist_items, :list_name, :list_id

  def todoist_priority
    # Maps MS Todo importance → Todoist priority
    { 'low' => 4, 'normal' => 4, 'high' => 1 }[@importance] || 4
  end

  def total_task_count
    1 + checklist_items.size  # Parent + subtasks
  end
end
```

### GraphClient

**File:** `lib/export_ms_todo/graph_client.rb`

HTTP client for MS Graph API with retry logic:

```ruby
class ExportMsTodo::GraphClient
  def get(path)
    get_with_retry(path)
  end

  private

  def get_with_retry(path, retries = 3)
    # Handles:
    # - 401: AuthenticationError
    # - 429: RateLimitError (exponential backoff)
    # - 5xx: Retry with exponential backoff
  end
end
```

**Testing:** Mocked with WebMock/VCR

### TaskRepository

**File:** `lib/export_ms_todo/task_repository.rb`

Orchestrates data fetching:

```ruby
class ExportMsTodo::TaskRepository
  def fetch_all_tasks
    lists = fetch_lists
    lists.map do |list|
      tasks = fetch_tasks_for_list(list['id'])
      { list: list, tasks: enrich_with_checklists(tasks, list) }
    end
  end
end
```

**Key methods:**
- `fetch_lists` - Get non-system lists
- `fetch_tasks_for_list` - Get tasks with pagination
- `fetch_checklist_items` - Get subtasks for a task

### RecurrenceMapper

**File:** `lib/export_ms_todo/recurrence_mapper.rb`

Converts MS Todo recurrence → Todoist natural language:

```ruby
class ExportMsTodo::RecurrenceMapper
  def map(recurrence)
    pattern_type = recurrence.dig('pattern', 'type')
    send("map_#{pattern_type}")  # Dynamic dispatch
  rescue NoMethodError
    warn "Unknown pattern: #{pattern_type}"
    fallback_mapping
  end
end
```

**Test coverage:** 20+ test cases for all patterns

### TodoistCSV Exporter

**File:** `lib/export_ms_todo/exporters/todoist_csv.rb`

KISS principle applied:

```ruby
def export(grouped_tasks)
  grouped_tasks.flat_map do |group|
    if total_task_count(tasks) <= 300
      single_file_export(list, tasks)  # Simple path (80%)
    else
      TaskChunker.new(list, tasks, self).export  # Complex path
    end
  end
end
```

**Features:**
- Proper CSV escaping (commas, quotes, newlines)
- Subtask handling (INDENT=2)
- Recurrence integration

### TaskChunker

**File:** `lib/export_ms_todo/exporters/task_chunker.rb`

Handles lists with 300+ tasks:

```ruby
def split_tasks_into_chunks
  # Keeps parent + subtasks together
  # Warns if single task exceeds 300
  # Returns array of task chunks
end
```

---

## Testing

### Test Stack

- **RSpec** - Test framework
- **VCR** - Record HTTP interactions
- **WebMock** - Mock HTTP requests
- **Rack::Test** - Test Sinatra API

### Running Tests

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/export_ms_todo/recurrence_mapper_spec.rb

# With coverage
bundle exec rspec --format documentation

# Specific test
bundle exec rspec spec/export_ms_todo/task_spec.rb:42
```

### Test Structure

**Unit tests:**
```ruby
# spec/export_ms_todo/task_spec.rb
RSpec.describe ExportMsTodo::Task do
  describe '#todoist_priority' do
    it 'maps high importance to priority 1' do
      task = described_class.new('importance' => 'high')
      expect(task.todoist_priority).to eq(1)
    end
  end
end
```

**Integration tests (with VCR):**
```ruby
# spec/export_ms_todo/task_repository_spec.rb
RSpec.describe ExportMsTodo::TaskRepository do
  describe '#fetch_all_tasks', :vcr do
    it 'fetches tasks with checklists' do
      tasks = repo.fetch_all_tasks
      expect(tasks.first[:tasks].first.checklist_items).to be_an(Array)
    end
  end
end
```

### VCR Cassettes

**Recording cassettes:**
```bash
# Set real token
export MS_TODO_TOKEN="Bearer REAL_TOKEN"

# Run tests (will record HTTP interactions)
bundle exec rspec --tag vcr

# Cassettes saved to spec/fixtures/vcr_cassettes/
```

**Important:** Never commit cassettes with real tokens! VCR automatically filters tokens.

### Test Coverage Goals

- **Overall:** 90%+
- **RecurrenceMapper:** 100% (critical logic)
- **CSV escaping:** 100% (data integrity)
- **API endpoints:** 100% (public interface)

---

## Code Style

### Ruby Style Guide

Follow standard Ruby conventions:
- 2 spaces for indentation
- `snake_case` for methods and variables
- `CamelCase` for classes and modules
- `SCREAMING_SNAKE_CASE` for constants

### Design Patterns

**Dependency Injection:**
```ruby
# Good
class TaskRepository
  def initialize(client)
    @client = client
  end
end

repo = TaskRepository.new(GraphClient.new(token))
```

**Single Responsibility:**
```ruby
# GraphClient: HTTP only
# TaskRepository: Business logic
# TodoistCSV: Export only
```

**KISS for Complexity:**
```ruby
# Simple case: direct implementation
# Complex case: delegate to specialist class

if simple?
  simple_implementation
else
  ComplexHandler.new.handle
end
```

### Error Handling

**Custom exceptions:**
```ruby
module ExportMsTodo
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class RateLimitError < Error; end
end
```

**Usage:**
```ruby
raise AuthenticationError, 'Token expired' if response.code == 401
```

---

## Contribution Workflow

### 1. Find or Create an Issue

- Check [existing issues](https://github.com/scurry/export-ms-todo/issues)
- Create new issue for bugs/features
- Discuss approach before major changes

### 2. Create a Branch

```bash
# Feature branch
git checkout -b feature/add-categories-support

# Bugfix branch
git checkout -b fix/csv-escaping-quotes
```

### 3. Write Tests First (TDD)

```ruby
# 1. Write failing test
it 'escapes quotes in task titles' do
  task = Task.new('title' => 'Task with "quotes"')
  csv = exporter.export([{ list: list, tasks: [task] }])
  expect(csv).to include('Task with ""quotes""')
end

# 2. Run (should fail)
bundle exec rspec spec/export_ms_todo/exporters/todoist_csv_spec.rb

# 3. Implement
def escape_csv_field(text)
  # Implementation
end

# 4. Run (should pass)
```

### 4. Commit with Conventional Commits

```bash
git commit -m "feat: add categories to Todoist labels mapping"
git commit -m "fix: properly escape quotes in CSV titles"
git commit -m "docs: update USER_GUIDE with categories section"
git commit -m "test: add recurrence pattern edge cases"
```

**Prefixes:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `test:` - Tests
- `refactor:` - Code refactoring
- `chore:` - Maintenance

### 5. Push and Create PR

```bash
git push origin feature/add-categories-support
```

Create pull request with:
- Clear description of changes
- Link to related issue
- Screenshots (if UI changes)
- Test results

### 6. Code Review

- Address feedback
- Update tests if needed
- Squash commits if requested

---

## Release Process

### Version Numbering

Semantic versioning (SemVer):
- `0.1.0` - Major.Minor.Patch
- `0.2.0` - Minor version (new features)
- `0.1.1` - Patch version (bug fixes)

### Release Checklist

1. **Update version**
   ```ruby
   # lib/export_ms_todo/version.rb
   VERSION = '0.2.0'
   ```

2. **Update CHANGELOG**
   ```markdown
   ## [0.2.0] - 2025-01-15
   ### Added
   - Category to label mapping
   - Reminder date support
   ```

3. **Run full test suite**
   ```bash
   bundle exec rspec
   # Ensure 100% pass rate
   ```

4. **Tag release**
   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0"
   git push origin v0.2.0
   ```

5. **Create GitHub release**
   - Go to Releases → Draft new release
   - Select tag `v0.2.0`
   - Copy CHANGELOG entry
   - Publish

---

## Debugging

### Enable Debug Output

```bash
# Set DEBUG environment variable
DEBUG=1 bundle exec bin/export-ms-todo export
```

### Inspect HTTP Requests

```ruby
# In lib/export_ms_todo/graph_client.rb
def get_with_retry(path, retries = 3)
  puts "DEBUG: GET #{path}" if ENV['DEBUG']
  # ...
end
```

### Test with Real Data

```bash
# Export as JSON to inspect task structure
bundle exec bin/export-ms-todo export --format json --output debug.json

# Pretty print JSON
cat debug.json | jq .
```

---

## Resources

- **MS Graph API Docs:** https://learn.microsoft.com/en-us/graph/api/resources/todo-overview
- **Todoist CSV Format:** https://todoist.com/help/articles/import-or-export-a-project-as-a-csv-file-in-todoist
- **Ruby Style Guide:** https://rubystyle.guide/
- **RSpec Docs:** https://rspec.info/

---

**[← User Guide](USER_GUIDE.md)** | **[Contributing →](CONTRIBUTING.md)**
