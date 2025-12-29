# frozen_string_literal: true

# lib/export_ms_todo/null_reporter.rb
module ExportMsTodo
  # No-op reporter for when progress reporting is not needed
  # Implements same interface as ProgressReporter but does nothing
  class NullReporter
    def start_export; end

    def finish_export; end

    def start_fetching(_list_count); end

    def fetching_list(_name, _current, _total); end

    def fetched_task(_task, _list_name); end

    def skipped_completed_task(_task); end

    def failed_task(_task_id, _error); end

    def print_summary; end

    def increment_total_tasks(_count = 1); end

    def increment_exported(_count = 1); end

    def increment_completed_skipped(_count = 1); end

    def increment_failed(_count = 1); end
  end
end
