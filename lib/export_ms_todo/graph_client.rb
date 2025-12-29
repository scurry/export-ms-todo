# frozen_string_literal: true

# lib/export_ms_todo/graph_client.rb
require 'httparty'
require 'time'

module ExportMsTodo
  class GraphClient
    include HTTParty

    base_uri 'https://graph.microsoft.com/v1.0'

    MAX_RETRIES = 3

    def initialize(token)
      @token = token.start_with?('Bearer ') ? token : "Bearer #{token}"
      @headers = { 'Authorization' => @token }
    end

    def get(path)
      get_with_retry(path)
    end

    private

    def get_with_retry(path, retries = MAX_RETRIES)
      response = self.class.get(path, headers: @headers)

      case response.code
      when 200..299
        response
      when 401
        raise AuthenticationError, 'Invalid or expired token'
      when 429
        retry_after = parse_retry_after(response.headers['Retry-After'])
        raise RateLimitError, "Rate limit exceeded. Retry after #{retry_after} seconds" unless retries.positive?

        warn "Rate limit exceeded. Waiting #{retry_after} seconds..."
        sleep(retry_after)
        get_with_retry(path, retries - 1)

      when 500..599
        raise Error, "Server error: #{response.code}" unless retries.positive?

        sleep(2**(MAX_RETRIES - retries)) # Exponential backoff
        get_with_retry(path, retries - 1)

      else
        raise Error, "Unexpected response: #{response.code}"
      end
    end

    def parse_retry_after(header_val)
      return 60 if header_val.nil? || header_val.empty?

      if header_val.match?(/^\d+$/)
        header_val.to_i
      else
        # Handle HTTP Date format
        (Time.httpdate(header_val) - Time.now).to_i
      end
    rescue StandardError
      60 # Fallback default
    end
  end
end
