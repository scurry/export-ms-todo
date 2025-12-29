# spec/cli_spec.rb
require 'spec_helper'
require 'thor'

RSpec.describe 'CLI' do
  let(:cli_path) { File.expand_path('../bin/export-ms-todo', __dir__) }

  describe 'bin/export-ms-todo' do
    it 'exists and is executable' do
      expect(File.exist?(cli_path)).to be true
      expect(File.executable?(cli_path)).to be true
    end

    it 'loads without errors' do
      # Just verify the file can be loaded
      expect { load cli_path }.not_to raise_error
    end
  end

  describe 'ExportMsTodo::CLI' do
    before do
      load cli_path
    end

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
