# api/app.rb
require 'dotenv/load' if ENV['RACK_ENV'] != 'production'
require 'sinatra/base'
require 'json'
require 'zip'
require_relative '../lib/export_ms_todo'
require_relative '../lib/export_ms_todo/graph_client'
require_relative '../lib/export_ms_todo/task_repository'
require_relative '../lib/export_ms_todo/exporters/todoist_csv'
require_relative '../lib/export_ms_todo/exporters/json'

module ExportMsTodo
  class API < Sinatra::Base
    configure do
      set :show_exceptions, false
      set :raise_errors, false
      set :protection, except: [:json_csrf] if ENV['RACK_ENV'] == 'test'
    end

    # Health check
    get '/health' do
      content_type :json
      { status: 'ok', version: VERSION }.to_json
    end

    # Get lists (preview)
    get '/lists' do
      token = params[:token]
      halt 400, { error: 'Token required' }.to_json unless token

      client = GraphClient.new(token)
      repo = TaskRepository.new(client)
      lists = repo.fetch_lists

      content_type :json
      {
        lists: lists.map { |l| { id: l['id'], name: l['displayName'] } }
      }.to_json
    rescue AuthenticationError => e
      halt 401, { error: e.message }.to_json
    rescue RateLimitError => e
      halt 429, { error: e.message }.to_json
    rescue => e
      halt 500, { error: e.message }.to_json
    end

    # Export tasks
    post '/export' do
      token = params[:token]
      halt 400, { error: 'Token required' }.to_json unless token

      format = params[:format] || 'csv'
      halt 400, { error: 'Invalid format' }.to_json unless ['csv', 'json'].include?(format)

      single_file = params[:single_file] == 'true' || params[:single_file] == true

      # Fetch tasks
      client = GraphClient.new(token)
      repo = TaskRepository.new(client)
      grouped_tasks = repo.fetch_all_tasks

      # Export
      exporter = format == 'json' ?
        Exporters::JSON.new : Exporters::TodoistCSV.new

      files = exporter.export(grouped_tasks)

      # Return response
      if single_file || files.size == 1
        file = files.first
        content_type format == 'json' ? 'application/json' : 'text/csv'
        attachment file[:filename]
        file[:content]
      else
        # Create ZIP
        zip_content = create_zip(files)

        content_type 'application/zip'
        attachment 'ms-todo-export.zip'
        zip_content
      end
    rescue AuthenticationError => e
      halt 401, { error: e.message }.to_json
    rescue RateLimitError => e
      halt 429, { error: e.message }.to_json
    rescue => e
      halt 500, { error: e.message }.to_json
    end

    private

    def create_zip(files)
      zip_stream = Zip::OutputStream.write_buffer do |zip|
        files.each do |file|
          zip.put_next_entry(file[:filename])
          zip.write file[:content]
        end
      end

      zip_stream.rewind
      zip_stream.read
    end
  end
end
