# frozen_string_literal: true

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
      @overrides = normalize_overrides(overrides)

      merge_configs!
    end

    private

    def normalize_overrides(overrides)
      # Convert symbol keys to strings and flatten single-level overrides
      normalized = {}

      overrides.each do |key, value|
        string_key = key.to_s

        # Handle special keys that map to nested config
        case string_key
        when 'output_path'
          normalized['output'] ||= {}
          normalized['output']['path'] = value
        when 'output_format'
          normalized['output'] ||= {}
          normalized['output']['format'] = value
        when 'single_file'
          normalized['output'] ||= {}
          normalized['output']['single_file'] = value
        when 'token'
          normalized['token'] = value
        else
          normalized[string_key] = value
        end
      end

      normalized
    end

    def load_yaml(path)
      return {} unless File.exist?(path)

      YAML.load_file(path) || {}
    rescue StandardError => e
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
      output = {}
      output['format'] = ENV['MS_TODO_FORMAT'] if ENV['MS_TODO_FORMAT']
      output['path'] = ENV['MS_TODO_OUTPUT_PATH'] if ENV['MS_TODO_OUTPUT_PATH']
      output['single_file'] = (ENV['MS_TODO_SINGLE_FILE'] == 'true') if ENV['MS_TODO_SINGLE_FILE']

      config = {}
      config['output'] = output if output.any?
      config['token'] = ENV['MS_TODO_TOKEN'] if ENV['MS_TODO_TOKEN']

      config
    end

    def merge_configs!
      # Priority: overrides > env > file > defaults
      config = deep_merge(@defaults, @file_config)
      config = deep_merge(config, @env_config)
      config = deep_merge(config, @overrides)

      # Set instance variables
      @output_format = config.dig('output', 'format') || 'csv'
      @single_file = config.dig('output', 'single_file').nil? ? false : config.dig('output', 'single_file')
      @output_path = config.dig('output', 'path') || './ms-todo-export'
      @include_completed = config.dig('csv', 'include_completed').nil? ? false : config.dig('csv', 'include_completed')
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
