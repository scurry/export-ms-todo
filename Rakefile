# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# Default task - run tests
task default: :test

# Test task
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.verbose = false
end

# Lint task
RuboCop::RakeTask.new(:lint) do |t|
  t.options = ['--display-cop-names']
end

# Auto-fix lint issues
RuboCop::RakeTask.new('lint:fix') do |t|
  t.options = ['--auto-correct-all', '--display-cop-names']
end

# Security audit
desc 'Check for vulnerable dependencies'
task :audit do
  sh 'bundle exec bundle-audit check --update'
end

# Run all quality checks
desc 'Run all quality checks (tests, lint, audit)'
task quality: %i[test lint audit]

# CI task - same as quality
desc 'Run CI checks (same as quality)'
task ci: :quality
