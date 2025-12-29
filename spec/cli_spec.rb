# frozen_string_literal: true

# spec/cli_spec.rb
require 'spec_helper'
require 'thor'

# Load CLI only once
CLI_PATH = File.expand_path('../bin/export-ms-todo', __dir__)
load CLI_PATH unless defined?(ExportMsTodo::CLI)

RSpec.describe 'CLI' do
  describe 'bin/export-ms-todo' do
    let(:cli_path) { File.expand_path('../bin/export-ms-todo', __dir__) }

    it 'exists and is executable' do
      expect(File.exist?(cli_path)).to be true
      expect(File.executable?(cli_path)).to be true
    end

    it 'loads without errors' do
      # Already loaded via require_relative above
      expect(defined?(ExportMsTodo::CLI)).to be_truthy
    end
  end

  describe 'ExportMsTodo::CLI' do
    it 'defines the CLI class' do
      expect(defined?(ExportMsTodo::CLI)).to be_truthy
      expect(ExportMsTodo::CLI.ancestors).to include(Thor)
    end

    it 'has export command' do
      commands = ExportMsTodo::CLI.commands
      expect(commands).to have_key('export')
    end

    it 'has version command' do
      commands = ExportMsTodo::CLI.commands
      expect(commands).to have_key('version')
    end
  end
end
