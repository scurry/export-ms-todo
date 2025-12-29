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
