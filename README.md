# Export MS Todo

<div align="center">

![Ruby](https://img.shields.io/badge/Ruby-3.2+-CC342D?style=flat&logo=ruby&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)

**Export Microsoft To Do tasks to Todoist CSV format**

A Ruby CLI and API tool for migrating tasks from Microsoft To Do to Todoist (and other task managers).

[Quick Start](#quick-start) •
[Features](#features) •
[Documentation](#documentation) •
[Contributing](#contributing)

</div>

---

## 📋 Table of Contents

- [About](#about)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## 🎯 About

Microsoft To Do doesn't provide a built-in export feature, making migration to other task managers difficult. **Export MS Todo** solves this by:

- Fetching all your tasks via Microsoft Graph API
- Preserving task metadata (priorities, due dates, subtasks, recurrence)
- Generating Todoist-compatible CSV files
- Handling edge cases (special characters, large lists >300 tasks)

Originally created for personal use, shared openly to help others migrate their tasks.

## ✨ Features

- ✅ **Complete task export** - Titles, descriptions, priorities, due dates, timezones
- 📝 **Subtask support** - Converts MS Todo checklist items to Todoist subtasks
- 🔄 **Recurrence patterns** - Daily, weekly, monthly, yearly with custom intervals
- 📊 **Large list handling** - Automatic splitting for lists over 300 tasks
- 🎨 **Dual interfaces** - Both CLI (command-line) and REST API
- ⚙️ **Zero-config** - Works with just your MS Graph token
- 🐛 **JSON export** - Debug format for inspecting task data
- 🔐 **Secure** - Token never stored, only used during export

### Field Mapping

| MS Todo | Todoist CSV | Notes |
|---------|-------------|-------|
| Title | CONTENT | Properly escaped for commas, quotes |
| Body/Notes | DESCRIPTION | Full notes preserved |
| High priority | PRIORITY 1 | Top priority in Todoist |
| Normal/Low priority | PRIORITY 4 | Standard priority |
| Checklist items | Subtasks (INDENT=2) | Maintains parent-child relationship |
| Due date | DATE | ISO format or natural language |
| Timezone | TIMEZONE | Preserved from MS Todo |
| Recurrence | DATE field | Converted to Todoist syntax |

## 🚀 Quick Start

### Prerequisites

- Ruby 3.2 or higher
- Microsoft account with To Do tasks
- MS Graph API token ([Get it here](https://developer.microsoft.com/en-us/graph/graph-explorer))

### Installation

```bash
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo
bundle install
```

### Basic Usage

```bash
# Set up your token (one time)
cp .env.example .env
# Edit .env and paste your MS Graph token

# Export your tasks (creates ZIP with CSV files)
bundle exec bin/export-ms-todo export

# That's it! Import the CSV files to Todoist
```

📖 **[See detailed Quick Start guide →](docs/QUICK_START.md)**

## 📥 Installation

### From Source

```bash
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo
bundle install
```

### Getting Your MS Graph Token

1. Visit [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. Sign in with your Microsoft account
3. Select **"my To Do task lists"** from samples
4. Click **"Modify permissions"** → Consent to **"Tasks.ReadWrite"**
5. Navigate to **"Access token"** tab
6. Copy the token (starts with "eyJ...")

⚠️ **Security Note:** This token expires after ~1 hour. Generate a fresh one each time you export.

## 💻 Usage

### CLI (Command Line)

```bash
# Basic export (creates ms-todo-export.zip)
bundle exec bin/export-ms-todo export

# Custom output path
bundle exec bin/export-ms-todo export --output ~/Desktop/tasks

# Single CSV file instead of ZIP
bundle exec bin/export-ms-todo export --single-file

# JSON format for debugging
bundle exec bin/export-ms-todo export --format json

# Specify token via command line
bundle exec bin/export-ms-todo export --token "Bearer YOUR_TOKEN"
```

### API (REST)

```bash
# Start the API server
bundle exec rackup api/config.ru -p 3000

# Export via API (returns ZIP)
curl -X POST http://localhost:3000/export \
  -d "token=Bearer YOUR_TOKEN" \
  --output export.zip

# Get list preview
curl "http://localhost:3000/lists?token=Bearer YOUR_TOKEN"

# Health check
curl http://localhost:3000/health
```

### Importing to Todoist

1. Go to **Todoist** → **Settings** → **Import**
2. Upload each CSV file
3. For split lists (e.g., `Work-1.csv`, `Work-2.csv`), import all parts to the **same project**

📖 **[See full User Guide →](docs/USER_GUIDE.md)**

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Quick Start Guide](docs/QUICK_START.md) | Get started in 5 minutes |
| [User Guide](docs/USER_GUIDE.md) | Comprehensive usage documentation |
| [Developer Guide](docs/DEVELOPER_GUIDE.md) | Architecture, setup, contributing |
| [Design Document](docs/plans/2025-12-29-export-ms-todo-design.md) | Technical design and decisions |
| [Implementation Plan](docs/plans/2025-12-29-export-ms-todo.md) | Step-by-step build plan |

## 🗺️ Roadmap

### v0.1.0 (Current)
- ✅ Basic task export (title, priority, due dates)
- ✅ Subtask support (checklist items)
- ✅ Recurrence pattern mapping
- ✅ Large list handling (>300 tasks)
- ✅ CLI and API interfaces

### v0.2.0 (Planned)
- ⏳ Reminder dates support
- ⏳ File attachment handling
- ⏳ Categories → Todoist labels
- ⏳ Complex recurrence patterns
- ⏳ Web UI for non-technical users

### Future
- 💭 Bidirectional sync
- 💭 Support for other task managers (TickTick, Things, etc.)
- 💭 Automated scheduled exports

[View open issues](https://github.com/scurry/export-ms-todo/issues) • [Suggest a feature](https://github.com/scurry/export-ms-todo/issues/new)

## 🤝 Contributing

Contributions are welcome! Whether it's:

- 🐛 Bug reports
- 💡 Feature requests
- 📖 Documentation improvements
- 🔧 Code contributions

**Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.**

### Development Quick Start

```bash
# Clone and setup
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo
bundle install

# Run tests
bundle exec rspec

# Run with real token (careful with VCR cassettes)
export MS_TODO_TOKEN="Bearer YOUR_TOKEN"
bundle exec bin/export-ms-todo export --format json
```

📖 **[See full Developer Guide →](docs/DEVELOPER_GUIDE.md)**

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

This is a permissive license that allows you to use, modify, and distribute the software freely.

## 🙏 Acknowledgments

- **Inspiration:** [Microsoft-To-Do-Export](https://github.com/daylamtayari/Microsoft-To-Do-Export) by Daylam Tayari (Java implementation)
- **Microsoft Graph API** - For providing access to To Do data
- **Todoist** - For their importable CSV format
- **Ruby community** - For excellent tools (Thor, Sinatra, RSpec)

---

<div align="center">

**Built with ❤️ by [@scurry](https://github.com/scurry)**

[Report Bug](https://github.com/scurry/export-ms-todo/issues) •
[Request Feature](https://github.com/scurry/export-ms-todo/issues) •
[Ask Question](https://github.com/scurry/export-ms-todo/discussions)

</div>
