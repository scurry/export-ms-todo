# Export MS Todo - Design Document

**Date:** 2025-12-29
**Project:** export-ms-todo
**Purpose:** Ruby utility to export Microsoft To Do tasks to Todoist CSV format

## Overview

A Ruby-based tool that exports Microsoft To Do tasks to Todoist-compatible CSV format, with both CLI and API interfaces. Handles comprehensive task data including subtasks, notes, recurrence patterns, priorities, and due dates.

### Design Principles

- **KISS**: Simple path for common cases, complexity only when needed
- **DRY**: Shared business logic between CLI and API
- **SOLID**: Single responsibility, dependency injection, extensible design
- **Zero-config**: Works out of the box with just a token

## Architecture

### Monorepo Structure

```
export-ms-todo/
├── lib/export_ms_todo/
│   ├── graph_client.rb        # MS Graph HTTP client (Auth, Retries)
│   ├── task_repository.rb     # Data fetching orchestration
│   ├── task.rb                # Rich task model
│   ├── config.rb              # Hybrid configuration
│   ├── recurrence_mapper.rb   # Recurrence pattern mapping
│   ├── utils.rb               # Shared utilities (filename sanitization)
│   ├── exporters/
│   │   ├── base.rb
│   │   ├── todoist_csv.rb     # CSV generation
│   │   ├── task_chunker.rb    # Handle >300 task lists
│   │   └── json.rb            # Debug JSON output
│   └── version.rb
├── bin/export-ms-todo         # CLI executable (Thor)
├── api/
│   ├── app.rb                 # Sinatra API
│   └── config.ru              # Rack config
├── config/
│   ├── default.yml            # Default settings
│   └── puma.rb                # API server config
├── .env.example               # Token template
├── Gemfile
└── spec/                      # RSpec tests
```

### Key Dependencies

- **Thor**: CLI framework
- **Sinatra**: Lightweight API framework
- **httparty**: HTTP client for MS Graph API
- **rubyzip**: ZIP file generation
- **dotenv**: Environment variable management

## Data Model

### Task Object

```ruby
class ExportMsTodo::Task
  attr_accessor :id, :title, :body, :importance, :status,
                :due_date, :due_timezone,
                :recurrence, :checklist_items,
                :list_name, :list_id,
                :created_at, :updated_at

  def todoist_priority
    # MS Todo: low=0, normal=1, high=2
    # Todoist: 4=lowest, 1=highest
    { 'low' => 4, 'normal' => 4, 'high' => 1 }[@importance] || 4
  end

  def subtasks
    @checklist_items.map { |item| Subtask.new(item) }
  end
end
```

### v1 Feature Scope

**Must-have (v1):**
- Task title, due dates, priority
- Steps/checklist items → Todoist subtasks (INDENT)
- Task body/notes → Description field
- Basic recurrence patterns (daily, weekly, monthly, yearly with intervals)
- List organization (one CSV per list)

**Nice-to-have (v2):**
- Reminder dates (append to description or skip)
- File attachments (append filenames to description)
- Categories → Todoist labels
- Complex recurrence edge cases

## MS Graph API Integration

### Separation of Concerns

**1. GraphClient (HTTP/Auth)**
Handles the raw HTTP communication, authentication headers, rate limiting (429), and retries (5xx).

```ruby
class ExportMsTodo::GraphClient
  BASE_URL = 'https://graph.microsoft.com/v1.0'

  def initialize(token)
    @token = "Bearer #{token}"
  end
  
  def get(path)
    fetch_with_retry(path)
  end

  private

  def fetch_with_retry(url, retries = 3)
    # Handles 401, 429 (rate limit), 500s with exponential backoff
  end
end
```

**2. TaskRepository (Business Logic)**
Orchestrates the fetching of lists, tasks, and checklists using the `GraphClient`.

```ruby
class ExportMsTodo::TaskRepository
  def initialize(client)
    @client = client
  end

  def fetch_all_tasks
    lists = fetch_lists
    lists.map do |list|
      tasks = fetch_tasks_for_list(list['id'])
      {
        list: list,
        tasks: tasks.map { |t| enrich_task(t, list) }
      }
    end
  end

  private

  def enrich_task(task_data, list)
    checklist = fetch_checklist_items(list['id'], task_data['id'])
    Task.new(task_data.merge(
      'checklistItems' => checklist,
      'listName' => list['displayName'],
      'listId' => list['id']
    ))
  end
end
```

### Data Flow

1. **Authenticate**: Token from .env or prompt
2. **Fetch Lists**: GET /me/todo/lists
3. **Fetch Tasks**: GET /me/todo/lists/{id}/tasks (with pagination)
4. **Fetch Checklist Items**: GET /me/todo/lists/{listId}/tasks/{taskId}/checklistItems
5. **Transform**: Parse into Task objects
6. **Export**: Generate CSV/JSON
7. **Package**: Create ZIP with multiple CSVs

## Export Strategy

### File Organization

**Default: One CSV per MS Todo list (preserves structure)**

```
ms-todo-export-2025-01-15.zip
├── Work.csv
├── Personal.csv
└── Shopping.csv
```

**Option: Single CSV with sections (--single-file flag)**

All lists merged into one CSV with TYPE=section separators.

### Handling Large Lists (>300 tasks)

Todoist CSV import limit: 300 tasks per file

**KISS Principle:**
- Lists ≤300 tasks: Simple direct export
- Lists >300 tasks: Delegate to TaskChunker

```ruby
# In TodoistCSV exporter
if total_task_count(tasks) <= MAX_TASKS_PER_FILE
  single_file_export(list, tasks)  # Simple path (80% case)
else
  TaskChunker.new(list, tasks, self).export  # Complex path
end
```

**TaskChunker ensures:**
- Parent task + subtasks stay together
- Files named: Work-1.csv, Work-2.csv, etc.
- User instructions for importing to same project

## Field Mapping

### MS Todo → Todoist CSV

| MS Todo Field | Todoist Column | Mapping Logic |
|---------------|----------------|---------------|
| `title` | CONTENT | Escape commas, quotes, newlines |
| `body` | DESCRIPTION | Task notes/description |
| `importance` | PRIORITY | low/normal→4, high→1 |
| Parent task | INDENT | 1 (top-level) |
| Checklist item | INDENT | 2 (subtask) |
| `dueDateTime.dateTime` | DATE | ISO or natural language |
| `dueDateTime.timeZone` | TIMEZONE | Pass through |
| `recurrence` | DATE | Convert to Todoist syntax |
| `listName` | (filename) | Separate CSV per list |

### CSV Special Character Escaping

```ruby
def escape_csv_field(text)
  return '' if text.nil?

  # Wrap in quotes if contains comma, quote, or newline
  if text.match?(/[,"\n]/)
    "\"#{text.gsub('"', '""')}\""
  else
    text
  end
end
```

### Recurrence Pattern Mapping

**Extensible, test-driven design:**

```ruby
class ExportMsTodo::RecurrenceMapper
  def map(recurrence)
    @recurrence = recurrence
    send("map_#{pattern_type}")
  rescue NoMethodError
    warn "Unknown recurrence pattern: #{pattern_type}"
    fallback_mapping
  end

  private

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

    # Last day of month (28-31)
    if day >= 28
      interval == 1 ? 'every month on the last day' :
                      "every #{interval} months on the last day"
    else
      interval == 1 ? "every month on the #{day}" :
                      "every #{interval} months on the #{day}"
    end
  end

  def map_relativeMonthly
    # "First Monday", "Last Friday", etc.
  end
end
```

**Test coverage: 20+ cases for all patterns and edge cases**

## Configuration System

### Hybrid Approach

**Priority order:**
1. CLI flags (highest)
2. Environment variables
3. Config file (~/.export-ms-todo.yml or ./config.yml)
4. Built-in defaults (config/default.yml)

### Default Configuration

```yaml
output:
  format: csv              # csv or json
  single_file: false       # One CSV per list (in ZIP)
  path: "./ms-todo-export"

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

### Token Handling

**Priority:**
1. CLI flag: `--token "Bearer ey..."`
2. `.env` file: `MS_TODO_TOKEN=Bearer ey...`
3. Interactive prompt

**Security:**
- Never log tokens
- .gitignore includes .env
- Clear error messages if invalid/expired

## CLI Interface (Thor)

### Commands

```bash
# Zero-config (prompts for token)
export-ms-todo

# With .env file
export-ms-todo

# Override output
export-ms-todo --output ~/Desktop/tasks

# Single file mode
export-ms-todo --single-file --output tasks.csv

# JSON debug mode
export-ms-todo --format json
```

### User Experience

```
$ export-ms-todo

╭─────────────────────────────────────────╮
│  Export MS Todo → Todoist              │
╰─────────────────────────────────────────╯

No token found. Please enter your MS Graph access token:
(Get it from: https://developer.microsoft.com/en-us/graph/graph-explorer)

Token: ████████████████

✓ Authenticated successfully
✓ Found 3 lists: Work, Personal, Shopping
✓ Fetching tasks...
  → Work: 450 tasks (split into 2 files due to 300-task limit)
  → Personal: 50 tasks
  → Shopping: 3 tasks

✓ Generating Todoist CSV files...
✓ Created ms-todo-export-2025-01-15.zip

Export complete!
📦 ms-todo-export-2025-01-15.zip (4 CSV files, 503 tasks total)

⚠️  Note: "Work" list split into 2 files:
   1. Import Work-1.csv to create "Work" project
   2. Import Work-2.csv to same "Work" project

Next steps:
1. Go to Todoist → Settings → Import
2. Upload CSV files (numbered files to same project)
```

## API Interface (Sinatra)

### Endpoints

**POST /export**
- Params: token (required), single_file (boolean), format (csv|json)
- Returns: ZIP file (multiple CSVs) or single CSV/JSON

**GET /lists**
- Params: token (required)
- Returns: Preview of available lists

**GET /health**
- Returns: Status and version

### Example

```bash
curl -X POST http://localhost:3000/export \
  -d "token=Bearer ey..." \
  -d "format=csv" \
  --output export.zip
```

### Response

```
HTTP/1.1 200 OK
Content-Type: application/zip
Content-Disposition: attachment; filename="ms-todo-export.zip"

[Binary ZIP file]
```

### Security

- No token storage
- CORS support (configurable)
- Rate limiting (proxy MS Graph limits)
- Never leak tokens in errors

## Error Handling

### Three Categories

**1. API Errors**
- 401: Clear "token expired" message
- 429: Exponential backoff with retry
- 500s: Retry with backoff

**2. Data Validation**
- Warn on unknown patterns (don't fail)
- Validate required fields
- Log edge cases for debugging

**3. Export Errors**
- Validate 300-task limit before export
- Partial export with warnings if needed
- Clear user messaging

## Testing Strategy

### Unit Tests (RSpec)

**RecurrenceMapper**: 20+ test cases
- All basic patterns (daily, weekly, monthly, yearly)
- Custom intervals (every 3 months)
- Days of week (every Monday and Wednesday)
- Last day of month edge cases
- Unknown pattern fallbacks

**CSV Escaping**: Special characters
- Commas in titles
- Quotes in content
- Newlines in descriptions

**TaskChunker**: Splitting logic
- Lists under 300 (simple path)
- Lists over 300 (chunking)
- Parent + subtasks stay together
- Edge case: task with 300+ subtasks

### Integration Tests (VCR)

- Real MS Graph API calls (recorded)
- Full end-to-end export flow
- Error scenarios (401, 429, 500)

### CLI Tests

```ruby
ExportMsTodo::CLI.start(['export', '--output=test.zip'])
expect(File.exist?('test.zip')).to be true
```

### API Tests (Rack::Test)

```ruby
post '/export', token: valid_token
expect(last_response).to be_ok
expect(last_response.headers['Content-Type']).to eq('application/zip')
```

## Success Criteria

- Zero-config works (prompt for token, sensible defaults)
- Handles 500+ task lists without error
- Preserves all v1 task data (title, dates, priority, subtasks, recurrence)
- CSV imports cleanly into Todoist
- 90%+ test coverage
- Clear error messages and user guidance
- CLI and API both functional

## Future Enhancements (v2)

- Reminder dates support
- File attachments handling
- Categories → Todoist labels
- Complex recurrence patterns (nth weekday, etc.)
- Bidirectional sync
- Web UI for non-technical users
