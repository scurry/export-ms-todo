# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-29

### Added
- **Core:** Initial release of the `export-ms-todo` gem.
- **Core:** Microsoft Graph API integration with automatic pagination and rate limit handling.
- **Export:** Support for exporting tasks to JSON format.
- **Export:** Support for exporting tasks to Todoist-compatible CSV format.
- **Export:** Automatic chunking of large task lists for Todoist CSV import limits.
- **API:** Sinatra-based API for handling export requests.
- **API:** `/health`, `/lists`, and `/export` endpoints.
- **CLI:** Basic command-line interface structure.
- **Docs:** Initial documentation including User Guide, Developer Guide, and Contributing guidelines.
