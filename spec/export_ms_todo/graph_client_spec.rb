# spec/export_ms_todo/graph_client_spec.rb
require 'spec_helper'
require 'export_ms_todo/graph_client'

RSpec.describe ExportMsTodo::GraphClient do
  let(:token) { 'Bearer test_token_123' }
  subject(:client) { described_class.new(token) }

  describe '#initialize' do
    it 'sets authorization header' do
      expect(client.instance_variable_get(:@token)).to eq(token)
    end

    it 'prepends Bearer if missing' do
      client_without_bearer = described_class.new('raw_token')
      expect(client_without_bearer.instance_variable_get(:@token)).to eq('Bearer raw_token')
    end
  end

  describe '#get', :vcr do
    it 'performs a GET request' do
      stub_request(:get, /graph.microsoft.com/)
        .to_return(status: 200, body: '{}')

      response = client.get('/me/todo/lists')
      expect(response.code).to eq(200)
    end

    describe 'error handling' do
      it 'raises AuthenticationError on 401' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 401)

        expect { client.get('/me') }.to raise_error(ExportMsTodo::AuthenticationError)
      end

      it 'raises RateLimitError on 429' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 429, headers: { 'Retry-After' => '60' })

        expect { client.get('/me') }.to raise_error(ExportMsTodo::RateLimitError)
      end

      it 'retries on 5xx errors' do
        stub_request(:get, /graph.microsoft.com/)
          .to_return(status: 500).then
          .to_return(status: 200, body: '{}')

        expect { client.get('/me') }.not_to raise_error
      end
    end
  end
end
