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
