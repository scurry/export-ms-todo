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
