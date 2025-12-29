# Progress Reporting Design

**Date:** 2025-12-29
**Status:** Approved
**Author:** Design session with user

## Problem Statement

Users exporting large numbers of MS Todo tasks (e.g., 10-minute exports) cannot tell if the process is stuck, broken, or just slow. The current implementation shows minimal feedback during the long-running fetch operation.

## Requirements

1. Show real-time progress during task fetching
2. Track comprehensive metrics:
   - Total tasks in MS Todo (including completed)
   - Total exported
   - Completed tasks (skipped)
   - Failed tasks (errors during fetch)
3. Display timing information (total duration)
4. Support verbose mode for debugging
5. Minimal performance impact (< 0.1% overhead)
6. Backwards compatible with existing code

## Design Overview

**Approach:** ProgressReporter class injected into TaskRepository

**Key benefits:**
- Clean separation of concerns
- Easy to test
- Supports both simple and verbose modes
- No blocking or performance impact
- Backwards compatible (optional injection)

## Section 1: ProgressReporter Class Structure

### Purpose
Centralize all progress tracking and output formatting.

### Core Responsibilities
- Track counts (total tasks in MS Todo, exported, completed/skipped, failed)
- Display progress updates (simple or verbose mode)
- Calculate and display timing information
- Generate final summary report

### Key Metrics
```ruby
class ProgressReporter
  attr_reader :total_tasks_in_ms     # All tasks found (including completed)
  attr_reader :exported_count         # Successfully exported
  attr_reader :completed_skipped      # Completed tasks (filtered out)
  attr_reader :failed_count           # Failed to fetch/process
  attr_reader :start_time             # For total duration
end
```

### Public Interface
```ruby
# Lifecycle
reporter.start_export                # Begin timing
reporter.finish_export               # End timing

# Progress updates
reporter.fetching_list(name, current, total)
reporter.fetched_task(task, list_name)
reporter.skipped_completed_task(task)
reporter.failed_task(task_id, error)

# Final output
reporter.print_summary              # Shows complete breakdown
```

### Verbose Mode
- **Enabled:** Shows each API call and task details
- **Disabled (default):** Shows only list-level progress like "Fetching 'Work' (2/5)..."

## Section 2: TaskRepository Integration

### Goal
Add progress hooks without cluttering the core fetch logic.

### Changes to TaskRepository
```ruby
class TaskRepository
  def initialize(client, reporter: nil)
    @client = client
    @reporter = reporter || NullReporter.new # No-op if not provided
  end

  def fetch_all_tasks
    lists = fetch_lists
    @reporter.start_fetching(lists.size)

    lists.map.with_index do |list, idx|
      @reporter.fetching_list(list['displayName'], idx + 1, lists.size)

      tasks_data = fetch_tasks_for_list(list['id'])

      tasks = tasks_data.map do |task_data|
        checklist = fetch_checklist_items(list['id'], task_data['id'])
        task = Task.new(task_data.merge(...))

        @reporter.fetched_task(task, list['displayName'])
        task
      end

      { list: list, tasks: tasks }
    end
  end
end
```

### Key Points
- `reporter: nil` parameter (optional, backwards compatible)
- `NullReporter` pattern - no conditionals, just call methods
- Progress calls don't interrupt flow
- Track completed/failed in existing error handling

### NullReporter Pattern
Simple class that responds to all reporter methods with no-ops, so code doesn't need `if @reporter` checks everywhere.

## Section 3: CLI Integration

### Goal
Wire up ProgressReporter to the CLI and add `--verbose` flag.

### Changes to bin/export-ms-todo
```ruby
desc 'export', 'Export MS Todo tasks to Todoist CSV format'
option :output, aliases: '-o', desc: 'Output path'
option :format, aliases: '-f', enum: %w[csv json], default: 'csv'
option :single_file, type: :boolean, default: false
option :token, aliases: '-t', desc: 'MS Graph access token'
option :verbose, type: :boolean, default: false, desc: 'Show detailed progress'

def export
  # ... existing setup code ...

  # Create reporter
  reporter = ProgressReporter.new(
    verbose: options[:verbose],
    output: self  # Pass Thor instance for colored output
  )

  # Inject into repository
  client = GraphClient.new(token)
  repo = TaskRepository.new(client, reporter: reporter)

  say '✓ Authenticated successfully', :green

  reporter.start_export
  grouped_tasks = repo.fetch_all_tasks  # Progress happens here
  reporter.finish_export

  # ... existing export code ...

  # Final summary
  reporter.print_summary
end
```

### New Output During Export
- **Default:** "Fetching 'Work' (2/5)...", "Fetching 'Personal' (3/5)..."
- **Verbose:** Shows each task as it's fetched

### Backwards Compatible
Works with existing code, no breaking changes.

## Section 4: Verbose Mode Implementation

### Goal
Show detailed progress in verbose mode without cluttering default output.

### Output Comparison

**Default mode (simple):**
```
✓ Authenticated successfully
Fetching tasks...
  → Work (1/3): 150 tasks
  → Personal (2/3): 45 tasks
  → Shopping (3/3): 12 tasks
Generating CSV files...
✓ Export complete!
```

**Verbose mode (`--verbose`):**
```
✓ Authenticated successfully
Fetching tasks...
  → Work (1/3)
    Fetching tasks... [API call]
    Found 150 tasks (120 active, 30 completed)
    Task: 'Review PR #123' (1/120)
    Task: 'Update documentation' (2/120)
    Fetching checklist for task 'Review PR #123'... [API call]
    ... (shows each task)
  → Personal (2/3)
    ... (detailed progress)
Generating CSV files...
  Work.csv: 120 tasks + 45 subtasks = 165 rows
  Personal.csv: 40 tasks + 15 subtasks = 55 rows
✓ Export complete!
```

### Implementation
```ruby
class ProgressReporter
  def fetched_task(task, list_name)
    return unless @verbose

    @output.say "    Task: '#{task.title}' (#{@current_task}/#{@list_task_count})"
  end

  def fetching_list(name, current, total)
    # Always show (both modes)
    @output.say "  → #{name} (#{current}/#{total})"
  end
end
```

### Future Enhancement
More granular details may be needed based on real usage patterns.

## Section 5: Final Summary Output

### Goal
Show comprehensive breakdown after export completes.

### Summary Format
```
✓ Export complete!
📦 ms-todo-export.zip

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Export Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total tasks in MS Todo:     207
  ✓ Exported:               175
  ⊘ Completed (skipped):     30
  ✗ Failed:                   2

Breakdown by list:
  Work:           120 exported, 25 completed, 0 failed
  Personal:        45 exported,  5 completed, 2 failed
  Shopping:        10 exported,  0 completed, 0 failed

Duration: 9m 42s

⚠️  Note: 2 tasks failed to export
Run with --verbose to see error details
```

### Implementation
```ruby
class ProgressReporter
  def print_summary
    duration = format_duration(Time.now - @start_time)

    @output.say "\n" + "━" * 50
    @output.say "Export Summary"
    @output.say "━" * 50 + "\n"

    @output.say "Total tasks in MS Todo:     #{@total_tasks_in_ms}"
    @output.say "  ✓ Exported:               #{@exported_count}", :green
    @output.say "  ⊘ Completed (skipped):     #{@completed_skipped}", :yellow
    @output.say "  ✗ Failed:                   #{@failed_count}", :red if @failed_count > 0

    # ... list breakdown ...

    @output.say "\nDuration: #{duration}"
  end
end
```

## Performance Impact

### Analysis
- **MS Graph API calls:** 50-500ms each (network bottleneck)
- **Progress updates:** ~1-10 microseconds (increment + format)
- **Terminal output:** ~100-1000 microseconds per line

### For Large Export (1000 tasks)
- Network time: 30-60 seconds
- Progress overhead: 10-50ms total
- **Impact: < 0.1%**

### Mitigation Strategies
1. **Batch terminal output** - Don't print every task in default mode
2. **Simple operations only** - Integer increments, basic string interpolation
3. **Conditional output** - Skip expensive formatting when not verbose

## Implementation Plan

### Files to Create
1. `lib/export_ms_todo/progress_reporter.rb` - Main reporter class
2. `lib/export_ms_todo/null_reporter.rb` - No-op implementation
3. `spec/export_ms_todo/progress_reporter_spec.rb` - Tests

### Files to Modify
1. `lib/export_ms_todo/task_repository.rb` - Add reporter injection
2. `bin/export-ms-todo` - Wire up reporter, add --verbose flag
3. `spec/export_ms_todo/task_repository_spec.rb` - Update tests

### Testing Strategy
- Unit tests for ProgressReporter (metrics tracking, output formatting)
- Integration tests with NullReporter (no output)
- Manual testing with verbose mode on large exports

## Success Criteria

1. ✓ Users can see progress during long-running exports
2. ✓ Final summary shows comprehensive breakdown
3. ✓ Verbose mode helps debug issues
4. ✓ Performance impact < 0.1%
5. ✓ Backwards compatible (existing code works unchanged)
6. ✓ No new dependencies required

## Future Enhancements

- More granular verbose output (API request/response details)
- Export to log file option
- Progress percentage for individual lists
- ETA (estimated time remaining) based on current rate
