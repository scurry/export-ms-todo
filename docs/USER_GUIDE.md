# User Guide

Comprehensive guide to using Export MS Todo.

## Table of Contents

- [Installation](#installation)
- [Getting Your Token](#getting-your-token)
- [CLI Usage](#cli-usage)
- [API Usage](#api-usage)
- [Configuration](#configuration)
- [Field Mapping](#field-mapping)
- [Importing to Todoist](#importing-to-todoist)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Installation

### Prerequisites

- **Ruby 3.2 or higher**
  - Check: `ruby --version`
  - Install: https://www.ruby-lang.org/en/documentation/installation/
- **Bundler**
  - Check: `bundle --version`
  - Install: `gem install bundler`
- **Git** (for cloning the repository)

### From Source

```bash
# Clone the repository
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo

# Install dependencies
bundle install

# Verify installation
bundle exec bin/export-ms-todo version
```

---

## Getting Your Token

Export MS Todo uses the Microsoft Graph API to access your tasks. You need an access token.

### Step-by-Step Token Generation

1. **Open Graph Explorer**
   - Navigate to: https://developer.microsoft.com/en-us/graph/graph-explorer

2. **Sign In**
   - Click **"Sign in to Graph Explorer"**
   - Use your **Microsoft account** (the one with your To Do tasks)

3. **Select Sample Query**
   - In the left sidebar, find **"To Do"** category
   - Click **"my To Do task lists"**

4. **Modify Permissions**
   - Click **"Modify permissions (Preview)"** in the top toolbar
   - Find **`Tasks.ReadWrite`**
   - Click **"Consent"**
   - Approve the permission request

5. **Copy Token**
   - Click **"Access token"** tab (next to Request headers)
   - Click **"Copy"** or manually select and copy the entire token
   - Token starts with `eyJ` and is very long (~2000 characters)

### Token Security & Expiration

⚠️ **Important:**
- Tokens expire after approximately **1 hour**
- Never commit tokens to git or share them publicly
- Generate a fresh token each time you export
- The `.env` file is already in `.gitignore` for safety

---

## CLI Usage

The command-line interface is the primary way to use Export MS Todo.

### Basic Command

```bash
bundle exec bin/export-ms-todo export
```

This will:
1. Check for `MS_TODO_TOKEN` in `.env` or prompt you
2. Fetch all your MS Todo lists and tasks
3. Generate Todoist CSV files
4. Create `ms-todo-export-YYYY-MM-DD.zip`

### Command Options

#### Specify Output Path

```bash
# Custom path (adds .zip extension automatically)
bundle exec bin/export-ms-todo export --output ~/Desktop/my-tasks

# Specific filename
bundle exec bin/export-ms-todo export --output ./exports/backup-2025-12-29
```

#### Change Output Format

```bash
# JSON format (for debugging or custom processing)
bundle exec bin/export-ms-todo export --format json

# CSV format (default)
bundle exec bin/export-ms-todo export --format csv
```

#### Single File Mode

```bash
# Merge all lists into one CSV file
bundle exec bin/export-ms-todo export --single-file --output combined.csv
```

**Note:** Todoist CSV import limit is 300 tasks per file. If you have more tasks, they'll be split across multiple files automatically.

#### Provide Token via CLI

```bash
# Don't use .env, provide token directly
bundle exec bin/export-ms-todo export --token "Bearer eyJ0eX..."
```

### CLI Output

**Successful export:**

```
╭─────────────────────────────────────────╮
│  Export MS Todo → Todoist              │
╰─────────────────────────────────────────╯

✓ Authenticated successfully
✓ Found 3 lists: Work, Personal, Shopping
✓ Fetching tasks...
  → Work: 450 tasks (split into 2 files due to 300-task limit)
  → Personal: 50 tasks
  → Shopping: 3 tasks

✓ Generating CSV files...
✓ Created ms-todo-export-2025-12-29.zip

Export complete!
📦 ms-todo-export-2025-12-29.zip (4 CSV files, 503 tasks total)

⚠️  Note: "Work" list split into 2 files:
   1. Import Work-1.csv to create "Work" project
   2. Import Work-2.csv to same "Work" project

Next steps:
1. Go to Todoist → Settings → Import
2. Upload CSV files (numbered files to same project)
```

**Error: Authentication Failed**

```
✗ Authentication failed
  Invalid or expired token
  Get a new token: https://developer.microsoft.com/en-us/graph/graph-explorer
```

**Error: Rate Limit**

```
✗ Rate limit exceeded
  Rate limit exceeded. Retry after 60 seconds
```

---

## API Usage

Export MS Todo includes a REST API for programmatic access.

### Starting the Server

```bash
# Development mode (default port 3000)
bundle exec rackup api/config.ru

# Custom port
bundle exec rackup api/config.ru -p 8080

# Production mode with Puma
bundle exec puma -C config/puma.rb
```

### API Endpoints

#### Health Check

**GET /health**

Check if the API is running.

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

#### List Preview

**GET /lists?token=BEARER_TOKEN**

Get a preview of your MS Todo lists (doesn't export).

```bash
curl "http://localhost:3000/lists?token=Bearer eyJ0eX..."
```

Response:
```json
{
  "lists": [
    { "id": "AAMkAD...", "name": "Work" },
    { "id": "AAMkAE...", "name": "Personal" }
  ]
}
```

#### Export Tasks

**POST /export**

Parameters:
- `token` (required) - MS Graph access token
- `format` (optional) - `csv` (default) or `json`
- `single_file` (optional) - `true` or `false` (default)

**CSV Export (ZIP file):**

```bash
curl -X POST http://localhost:3000/export \
  -d "token=Bearer eyJ0eX..." \
  -d "format=csv" \
  --output export.zip
```

**JSON Export:**

```bash
curl -X POST http://localhost:3000/export \
  -d "token=Bearer eyJ0eX..." \
  -d "format=json" \
  > export.json
```

**Single CSV file:**

```bash
curl -X POST http://localhost:3000/export \
  -d "token=Bearer eyJ0eX..." \
  -d "single_file=true" \
  --output export.csv
```

### API Error Responses

**400 Bad Request** - Missing or invalid parameters

```json
{
  "error": "Token required"
}
```

**401 Unauthorized** - Invalid or expired token

```json
{
  "error": "Invalid or expired token"
}
```

**429 Too Many Requests** - Rate limit exceeded

```json
{
  "error": "Rate limit exceeded. Retry after 60 seconds"
}
```

---

## Configuration

Export MS Todo uses a hybrid configuration system:

**Priority (highest to lowest):**
1. Command-line flags (`--output`, `--format`, etc.)
2. Environment variables (`MS_TODO_TOKEN`, etc.)
3. Config file (`~/.export-ms-todo.yml` or `./config.yml`)
4. Built-in defaults

### Environment Variables

Create a `.env` file in the project root:

```bash
# MS Graph access token
MS_TODO_TOKEN=Bearer eyJ0eXAiOiJKV1QiLCJub...

# Output path (default: ./ms-todo-export)
MS_TODO_OUTPUT_PATH=~/Desktop/tasks

# Output format: csv or json (default: csv)
MS_TODO_FORMAT=csv

# Single file mode: true or false (default: false)
MS_TODO_SINGLE_FILE=false
```

### Config File (Advanced)

Create `~/.export-ms-todo.yml`:

```yaml
output:
  format: csv
  single_file: false
  path: "~/Documents/ms-todo-exports"

csv:
  include_completed: false  # v2 feature
  priority_mapping:
    low: 4
    normal: 4
    high: 1

api:
  pagination_limit: 100
  timeout: 30
```

---

## Field Mapping

Understanding how MS Todo fields map to Todoist CSV format.

### Complete Mapping Table

| MS Todo Field | Todoist Column | Conversion Logic | Notes |
|---------------|----------------|------------------|-------|
| **Title** | CONTENT | Direct | Escaped for commas, quotes, newlines |
| **Body/Notes** | DESCRIPTION | Direct | Full notes preserved |
| **Importance: High** | PRIORITY | high → 1 | Highest priority in Todoist |
| **Importance: Normal** | PRIORITY | normal → 4 | Standard priority |
| **Importance: Low** | PRIORITY | low → 4 | Standard priority |
| **Checklist Items** | Subtasks | INDENT=2 | Each item becomes a subtask |
| **Due Date** | DATE | ISO 8601 | Format: `2025-01-20T10:00:00` |
| **Timezone** | TIMEZONE | Direct | Example: `America/New_York` |
| **Recurrence** | DATE | Converted | See [Recurrence Patterns](#recurrence-patterns) |
| **List Name** | Filename | `ListName.csv` | Each list becomes a separate file |
| **Status: Completed** | - | Excluded | Only incomplete tasks exported |

### Recurrence Patterns

MS Todo recurrence is converted to Todoist natural language:

| MS Todo Pattern | Todoist DATE Field | Example |
|-----------------|-------------------|---------|
| Daily | `every day` | - |
| Every N days | `every N days` | `every 3 days` |
| Weekly | `every week` | - |
| Every N weeks | `every N weeks` | `every 2 weeks` |
| Weekly on specific days | `every Mon and Wed` | `every Monday and Wednesday` |
| Monthly on day N | `every month on the N` | `every month on the 15` |
| Every N months | `every N months` | `every 3 months` |
| Last day of month | `every month on the last day` | - |
| First/Last Monday | `every first Monday` | `every last Friday` |
| Yearly | `every year` | - |

**Unsupported patterns:** If a pattern can't be mapped, it's logged and skipped. The task is still exported without recurrence.

### CSV Special Character Handling

Export MS Todo properly escapes:

**Commas in titles:**
```
"Buy milk, eggs, bread"  → Wrapped in quotes
```

**Quotes in text:**
```
Task with "quotes" → Task with ""quotes""
```

**Newlines in descriptions:**
```
Line 1
Line 2  → Preserved in DESCRIPTION field
```

---

## Importing to Todoist

### Import Process

1. **Extract ZIP** (if multiple files)
   ```bash
   unzip ms-todo-export-2025-12-29.zip
   ```

2. **Open Todoist**
   - Go to **Settings** → **Integrations** → **Import**

3. **Upload CSV Files**
   - Click **"From a template or a file"**
   - Select CSV file
   - Click **"Import"**

4. **Handle Split Lists**
   - For lists with 300+ tasks (e.g., `Work-1.csv`, `Work-2.csv`):
   - Import `Work-1.csv` → Creates "Work" project
   - Import `Work-2.csv` → **Select existing "Work" project** (don't create new)

### Post-Import

- **Review tasks** - Check that everything imported correctly
- **Adjust priorities** - Todoist may interpret priorities slightly differently
- **Fix recurrence** - Verify recurring tasks are set up correctly
- **Delete empty projects** - If any projects were created accidentally

### Todoist Limitations

- **300 tasks per import** - Export MS Todo splits automatically
- **No reminder dates** - MS Todo reminders don't map to Todoist (v2 feature planned)
- **No file attachments** - File names could be in description (v2 feature planned)

---

## Troubleshooting

### Authentication Issues

**Problem:** "Invalid or expired token"

**Solutions:**
- Tokens expire after ~1 hour - get a fresh one
- Make sure you copied the entire token (it's very long)
- Ensure token starts with `Bearer ` or add it: `MS_TODO_TOKEN=Bearer YOUR_TOKEN`
- Check that you consented to `Tasks.ReadWrite` permission

**Problem:** "Consent required"

**Solution:** In Graph Explorer, click "Modify permissions" and consent to `Tasks.ReadWrite`

### Export Issues

**Problem:** "No lists found"

**Solutions:**
- Verify you have tasks in Microsoft To Do
- Check that you're signed in with the correct account
- Try running the sample query in Graph Explorer first

**Problem:** Rate limit exceeded

**Solution:** Wait 60 seconds and try again. The API has built-in retry logic.

**Problem:** Task with 300+ subtasks

**Output:** Warning message logged. Task is exported but may fail Todoist import. Consider splitting the task manually.

### Import Issues

**Problem:** "Import failed" in Todoist

**Solutions:**
- Check CSV file is valid (open in Excel/Numbers)
- Ensure file is UTF-8 encoded
- Verify file size is under Todoist's limit
- Try importing a smaller subset first

**Problem:** Recurring tasks don't work

**Solution:** Some complex patterns may not be supported. Edit the task in Todoist after import.

**Problem:** Special characters mangled

**Solution:** Ensure file is UTF-8. Don't edit CSV in Excel (use VS Code or similar).

### Ruby/Bundle Issues

**Problem:** "Command not found: bundle"

**Solution:** Install Bundler: `gem install bundler`

**Problem:** "Ruby version too old"

**Solution:** Install Ruby 3.2+:
- macOS: `brew install ruby@3.2`
- Ubuntu: `sudo apt install ruby3.2`
- Windows: https://rubyinstaller.org/

---

## FAQ

### General

**Q: Is my data safe?**
A: Yes. The token is only used during export and never stored. Your tasks are exported locally to your machine. The tool doesn't send data anywhere except to Microsoft's Graph API to fetch your tasks.

**Q: Does this work with personal Microsoft accounts?**
A: Yes, it works with both personal and work/school accounts.

**Q: Can I export completed tasks?**
A: Currently only incomplete tasks are exported (v2 feature planned).

**Q: Does this delete my MS Todo tasks?**
A: No, it's read-only. Your MS Todo tasks remain untouched.

### Export

**Q: Why is my list split into multiple files?**
A: Todoist CSV import has a 300-task limit. Lists with 300+ tasks are automatically split. Import all parts to the same project.

**Q: Can I export to formats other than CSV?**
A: JSON is supported for debugging (`--format json`). Other formats planned for v2.

**Q: How long does export take?**
A: Typically 10-30 seconds for a few hundred tasks. Larger collections may take 1-2 minutes.

**Q: Can I schedule automatic exports?**
A: Not built-in yet (v3 feature). You can set up a cron job with a long-lived token.

### Import

**Q: What if I have 1000+ tasks?**
A: They'll be split into multiple CSV files. Import each to Todoist (takes a few minutes).

**Q: Can I import to apps other than Todoist?**
A: Any app supporting Todoist CSV format should work. Not tested with others yet.

**Q: Do subtasks import correctly?**
A: Yes, MS Todo checklist items become Todoist subtasks (INDENT=2).

### Development

**Q: Can I contribute?**
A: Yes! See [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

**Q: What's the tech stack?**
A: Ruby 3.2+, Thor (CLI), Sinatra (API), HTTParty (HTTP), RSpec (tests).

**Q: Where's the code?**
A: https://github.com/scurry/export-ms-todo

---

## Getting Help

- 📖 **[Developer Guide](DEVELOPER_GUIDE.md)** - Architecture, setup, contributing
- 🐛 **[Report a Bug](https://github.com/scurry/export-ms-todo/issues)**
- 💡 **[Request a Feature](https://github.com/scurry/export-ms-todo/issues)**
- 💬 **[Ask Questions](https://github.com/scurry/export-ms-todo/discussions)**

---

**[Back to README](../README.md)** | **[Developer Guide →](DEVELOPER_GUIDE.md)**
