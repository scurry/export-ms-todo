# frozen_string_literal: true

# spec/api_spec.rb
require 'spec_helper'
require 'rack/test'

RSpec.describe 'ExportMsTodo API' do
  include Rack::Test::Methods

  let(:valid_token) { 'Bearer test_token_123' }

  before do
    # Load the API app
    require_relative '../api/app'
  end

  def app
    ExportMsTodo::API
  end

  describe 'GET /health' do
    it 'returns health status' do
      get '/health'

      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)).to eq({
                                                     'status' => 'ok',
                                                     'version' => ExportMsTodo::VERSION
                                                   })
    end
  end

  describe 'GET /lists' do
    it 'requires token parameter' do
      get '/lists'

      expect(last_response.status).to eq(400)
    end

    it 'returns error for invalid token' do
      allow_any_instance_of(ExportMsTodo::GraphClient)
        .to receive(:get)
        .and_raise(ExportMsTodo::AuthenticationError, 'Invalid token')

      get '/lists', token: 'invalid'

      expect(last_response.status).to eq(401)
    end
  end

  describe 'POST /export' do
    it 'requires token parameter' do
      post '/export'

      expect(last_response.status).to eq(400)
    end

    it 'validates format parameter' do
      post '/export', token: valid_token, format: 'invalid'

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('Invalid format')
    end

    it 'handles authentication errors' do
      allow_any_instance_of(ExportMsTodo::GraphClient)
        .to receive(:get)
        .and_raise(ExportMsTodo::AuthenticationError, 'Invalid token')

      post '/export', token: 'invalid'

      expect(last_response.status).to eq(401)
    end

    it 'handles rate limit errors' do
      allow_any_instance_of(ExportMsTodo::TaskRepository)
        .to receive(:fetch_all_tasks)
        .and_raise(ExportMsTodo::RateLimitError, 'Rate limited')

      post '/export', token: valid_token

      expect(last_response.status).to eq(429)
    end
  end
end
