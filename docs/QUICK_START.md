# Quick Start Guide

**Get your MS Todo tasks exported in 5 minutes.**

## Step 1: Install Dependencies (2 minutes)

```bash
# Clone the repository
git clone https://github.com/scurry/export-ms-todo.git
cd export-ms-todo

# Install Ruby dependencies
bundle install
```

**Requirements:** Ruby 3.2+

## Step 2: Get Your Access Token (2 minutes)

1. Open [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. **Sign in** with your Microsoft account
3. From the samples, select **"my To Do task lists"**
4. Click **"Modify permissions"** (top right)
5. **Consent** to `Tasks.ReadWrite` permission
6. Go to **"Access token"** tab
7. **Copy** the entire token (starts with `eyJ...`)

> 💡 **Tip:** The token expires in ~1 hour. You'll need a fresh one each time.

## Step 3: Configure Token (30 seconds)

```bash
# Create .env file from template
cp .env.example .env

# Edit .env and paste your token
# It should look like:
# MS_TODO_TOKEN=Bearer eyJ0eXAiOiJKV1QiLCJub...
```

**Or** skip this and paste the token when prompted!

## Step 4: Export Your Tasks (30 seconds)

```bash
# Run the export
bundle exec bin/export-ms-todo export
```

You'll see output like:

```
╭─────────────────────────────────────────╮
│  Export MS Todo → Todoist              │
╰─────────────────────────────────────────╯

✓ Authenticated successfully
✓ Found 3 lists: Work, Personal, Shopping
✓ Fetching tasks...
  → Work: 12 tasks
  → Personal: 8 tasks
  → Shopping: 3 tasks

✓ Generating CSV files...
✓ Created ms-todo-export-2025-12-29.zip

Export complete!
📦 ms-todo-export-2025-12-29.zip
```

## Step 5: Import to Todoist (1 minute)

1. Extract the ZIP file
2. Go to **Todoist** → **Settings** → **Import**
3. Click **"From a template or a file"**
4. Upload each CSV file (one per MS Todo list)
5. Each CSV becomes a new Todoist project

**Done!** 🎉 Your tasks are now in Todoist.

---

## Common Options

### Export to Custom Location

```bash
bundle exec bin/export-ms-todo export --output ~/Desktop/my-tasks
```

### Export as JSON (for debugging)

```bash
bundle exec bin/export-ms-todo export --format json
```

### Single CSV File (all lists merged)

```bash
bundle exec bin/export-ms-todo export --single-file
```

---

## Troubleshooting

### "Authentication failed"

- Your token expired (they last ~1 hour)
- Get a fresh token from Graph Explorer

### "No lists found"

- Make sure you have tasks in Microsoft To Do
- Check that you consented to `Tasks.ReadWrite` permission

### "Command not found: bundle"

- Install Bundler: `gem install bundler`
- Or use full path: `/usr/bin/bundle install`

---

## Next Steps

- 📖 [Read the full User Guide](USER_GUIDE.md) for advanced options
- 🔧 [Check out the Developer Guide](DEVELOPER_GUIDE.md) to contribute
- 🐛 [Report issues](https://github.com/scurry/export-ms-todo/issues) you encounter

**Questions?** [Ask in Discussions](https://github.com/scurry/export-ms-todo/discussions)
