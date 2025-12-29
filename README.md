# Export MS Todo

Export Microsoft To Do tasks to Todoist CSV format.

## Quick Start

```bash
# Install dependencies
bundle install

# Set up your token
cp .env.example .env
# Edit .env and add your MS Graph token

# Run export
bundle exec export-ms-todo
```

## Development

```bash
# Run tests
bundle exec rspec

# Start API server
bundle exec rackup api/config.ru -p 3000
```

## License

GPL v3.0 (matching source Java project)
