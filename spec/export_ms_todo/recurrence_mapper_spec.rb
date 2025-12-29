# frozen_string_literal: true

# spec/export_ms_todo/recurrence_mapper_spec.rb
require 'spec_helper'
require 'export_ms_todo/recurrence_mapper'

RSpec.describe ExportMsTodo::RecurrenceMapper do
  subject(:mapper) { described_class.new }

  describe '#map' do
    context 'daily patterns' do
      it 'maps daily recurrence' do
        recurrence = { 'pattern' => { 'type' => 'daily', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every day')
      end

      it 'maps every N days' do
        recurrence = { 'pattern' => { 'type' => 'daily', 'interval' => 3 } }
        expect(mapper.map(recurrence)).to eq('every 3 days')
      end
    end

    context 'weekly patterns' do
      it 'maps weekly recurrence' do
        recurrence = { 'pattern' => { 'type' => 'weekly', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every week')
      end

      it 'maps every N weeks' do
        recurrence = { 'pattern' => { 'type' => 'weekly', 'interval' => 2 } }
        expect(mapper.map(recurrence)).to eq('every 2 weeks')
      end

      it 'maps specific days of week' do
        recurrence = {
          'pattern' => {
            'type' => 'weekly',
            'interval' => 1,
            'daysOfWeek' => %w[monday wednesday friday]
          }
        }
        expect(mapper.map(recurrence)).to eq('every Monday and Wednesday and Friday')
      end

      it 'maps every N weeks on specific days' do
        recurrence = {
          'pattern' => {
            'type' => 'weekly',
            'interval' => 2,
            'daysOfWeek' => ['tuesday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every 2 weeks on Tuesday')
      end
    end

    context 'monthly patterns' do
      it 'maps monthly on specific day' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 1,
            'dayOfMonth' => 15
          }
        }
        expect(mapper.map(recurrence)).to eq('every month on the 15')
      end

      it 'maps every N months on specific day' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 3,
            'dayOfMonth' => 1
          }
        }
        expect(mapper.map(recurrence)).to eq('every 3 months on the 1')
      end

      it 'maps last day of month' do
        recurrence = {
          'pattern' => {
            'type' => 'absoluteMonthly',
            'interval' => 1,
            'dayOfMonth' => 31
          }
        }
        expect(mapper.map(recurrence)).to eq('every month on the last day')
      end

      it 'maps relative monthly (first Monday)' do
        recurrence = {
          'pattern' => {
            'type' => 'relativeMonthly',
            'interval' => 1,
            'index' => 'first',
            'daysOfWeek' => ['monday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every first Monday')
      end

      it 'maps last Friday of month' do
        recurrence = {
          'pattern' => {
            'type' => 'relativeMonthly',
            'interval' => 1,
            'index' => 'last',
            'daysOfWeek' => ['friday']
          }
        }
        expect(mapper.map(recurrence)).to eq('every last Friday')
      end
    end

    context 'yearly patterns' do
      it 'maps yearly recurrence' do
        recurrence = { 'pattern' => { 'type' => 'absoluteYearly', 'interval' => 1 } }
        expect(mapper.map(recurrence)).to eq('every year')
      end

      it 'maps every N years' do
        recurrence = { 'pattern' => { 'type' => 'absoluteYearly', 'interval' => 2 } }
        expect(mapper.map(recurrence)).to eq('every 2 years')
      end
    end

    context 'unknown patterns' do
      it 'handles unknown pattern types gracefully' do
        recurrence = { 'pattern' => { 'type' => 'unknownPattern', 'interval' => 1 } }

        expect { mapper.map(recurrence) }.not_to raise_error
        expect(mapper.map(recurrence)).to match(/every/)
      end

      it 'logs warning for unknown patterns' do
        recurrence = { 'pattern' => { 'type' => 'customWeird' } }

        expect { mapper.map(recurrence) }.to output(/Unknown recurrence pattern/).to_stderr
      end
    end
  end
end
