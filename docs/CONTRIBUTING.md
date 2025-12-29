# Contributing to Export MS Todo

Thank you for considering contributing to Export MS Todo! 🎉

This document provides guidelines for contributing. Whether you're fixing a bug, adding a feature, or improving documentation, your help is appreciated.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Contribution Process](#contribution-process)
- [Coding Guidelines](#coding-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Documentation Guidelines](#documentation-guidelines)
- [Community](#community)

---

## Code of Conduct

This project follows a simple code of conduct:

- **Be respectful** - Treat everyone with respect
- **Be inclusive** - Welcome newcomers and diverse perspectives
- **Be constructive** - Focus on solutions, not just problems
- **Be patient** - Remember we're all learning

**Unacceptable behavior:**
- Harassment, discrimination, or personal attacks
- Trolling or deliberately inflammatory comments
- Publishing others' private information
- Any conduct that would be inappropriate in a professional setting

**Reporting:** Contact [@scurry](https://github.com/scurry) if you experience or witness unacceptable behavior.

---

## How Can I Contribute?

### 🐛 Reporting Bugs

**Before submitting a bug report:**
- Check [existing issues](https://github.com/scurry/export-ms-todo/issues) to avoid duplicates
- Try the latest version to see if it's already fixed
- Collect relevant information (error messages, steps to reproduce)

**Bug report template:**

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce:
1. Run command '...'
2. With configuration '...'
3. See error

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment:**
- OS: [e.g., macOS 14.0, Ubuntu 22.04]
- Ruby version: [e.g., 3.2.0]
- Export MS Todo version: [e.g., 0.1.0]

**Additional context**
Any other relevant information.
```

**Good bug reports:**
- **Specific** - Exact steps to reproduce
- **Reproducible** - Happens consistently
- **Unique** - Not a duplicate of existing issues
- **Scoped** - One bug per issue

### 💡 Suggesting Features

**Before suggesting a feature:**
- Check if it's already planned in [Roadmap](../README.md#roadmap)
- Search existing feature requests
- Consider if it fits the project's scope

**Feature request template:**

```markdown
**Problem**
What problem does this solve? What's the use case?

**Proposed solution**
How would you like this to work?

**Alternatives considered**
What other approaches did you consider?

**Additional context**
Mockups, examples, or references.
```

### 📖 Improving Documentation

Documentation improvements are always welcome!

- Fix typos or unclear wording
- Add examples or clarifications
- Improve formatting or organization
- Translate documentation (future)

Small fixes (typos, formatting) can be submitted directly. Larger changes should be discussed first.

### 🔧 Code Contributions

See [Development Setup](#development-setup) and [Contribution Process](#contribution-process) below.

---

## Development Setup

See **[Development Setup](DEVELOPER_GUIDE.md#development-setup)** in the Developer Guide for detailed setup instructions including:
- Prerequisites (Ruby, Bundler, MS Graph token)
- Initial setup steps
- Development workflow with worktrees

### Fork Setup (External Contributors)

```bash
# Fork the repository on GitHub
# Then clone YOUR fork (replace YOUR_USERNAME)
git clone https://github.com/YOUR_USERNAME/export-ms-todo.git
cd export-ms-todo

# Add upstream remote
git remote add upstream https://github.com/scurry/export-ms-todo.git

# Install dependencies
bundle install

# Set up code quality hooks
bundle exec overcommit --install
bundle exec overcommit --sign

# Set up environment
cp .env.example .env
# Edit .env and add your token

# Verify setup
bundle exec rspec
bundle exec bin/export-ms-todo version
```

**Code quality tools:**
- Pre-commit hooks run RuboCop and security checks automatically
- See **[Code Quality Tools](DEVELOPER_GUIDE.md#code-quality-tools)** for details

### Keeping Your Fork Updated

```bash
# Fetch and merge upstream changes
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

---

## Contribution Process

### 1. Create an Issue (if doesn't exist)

- Describe what you want to work on
- Get feedback before starting major changes
- Reference the issue in your PR later

### 2. Create a Branch

```bash
# Update your main branch first
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/add-categories-support

# Or bugfix branch
git checkout -b fix/csv-escaping-quotes
```

**Branch naming conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation
- `test/` - Test improvements
- `refactor/` - Code refactoring

**Advanced:** See **[Development Workflow](DEVELOPER_GUIDE.md#development-workflow-for-coding-agents-eg-claude-with-worktrees)** in the Developer Guide for git worktree workflow.

### 3. Make Your Changes

**Follow TDD (Test-Driven Development):**

```ruby
# 1. Write failing test
RSpec.describe ExportMsTodo::CategoryMapper do
  it 'maps MS Todo categories to Todoist labels' do
    categories = ['Work', 'Urgent']
    labels = mapper.map(categories)
    expect(labels).to eq(['@Work', '@Urgent'])
  end
end

# 2. Run test (should fail)
bundle exec rspec spec/export_ms_todo/category_mapper_spec.rb

# 3. Implement feature
class CategoryMapper
  def map(categories)
    categories.map { |c| "@#{c}" }
  end
end

# 4. Run test (should pass)
bundle exec rspec spec/export_ms_todo/category_mapper_spec.rb
```

**Commit frequently:**

```bash
# Stage changes
git add lib/export_ms_todo/category_mapper.rb
git add spec/export_ms_todo/category_mapper_spec.rb

# Commit with conventional commit message
git commit -m "feat: add category to label mapping"
```

### 4. Write Tests

- **New features:** Add tests covering the feature
- **Bug fixes:** Add test that fails without the fix, passes with it
- **Aim for 90%+ coverage** on new code

```bash
# Run tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/export_ms_todo/category_mapper_spec.rb
```

### 5. Update Documentation

If your change affects users:
- Update relevant docs (README, USER_GUIDE, etc.)
- Add examples
- Update field mapping tables

### 6. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/add-categories-support
```

**Create PR on GitHub:**
- Go to https://github.com/scurry/export-ms-todo
- Click "New Pull Request"
- Select your branch
- Fill out the template

**PR template:**

```markdown
## Description
Brief description of changes.

## Related Issue
Fixes #123 (link to issue)

## Changes Made
- Added category mapping
- Updated CSV exporter
- Added tests

## Testing
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Added tests for new functionality
- [ ] Tested manually with real MS Todo data

## Documentation
- [ ] Updated relevant documentation
- [ ] Added examples if needed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] No merge conflicts
```

### 7. Code Review Process

- Maintainer will review your PR
- Address feedback by pushing new commits
- Discussion happens in PR comments
- Be patient - reviews may take a few days

**After approval:**
- Maintainer will merge (or ask you to merge)
- Your contribution will be in the next release!

---

## Coding Guidelines

See **[Code Style](DEVELOPER_GUIDE.md#code-style)** in the Developer Guide for detailed guidelines on:
- Ruby style conventions (indentation, naming, etc.)
- Design principles (KISS, DRY, SOLID)
- Error handling patterns
- Dependency injection

**Quick reference:**
- 2 spaces for indentation
- `snake_case` for methods/variables
- `CamelCase` for classes
- Follow KISS, DRY, and Single Responsibility principles
- Use custom exceptions (`AuthenticationError`, `RateLimitError`)

---

## Testing Guidelines

See **[Testing](DEVELOPER_GUIDE.md#testing)** in the Developer Guide for detailed testing information including:
- Test structure (unit tests, integration tests with VCR)
- Test coverage goals
- VCR cassette recording
- Debugging with real data

**Requirements for contributions:**
- All new features must include tests
- Bug fixes must include a test that fails without the fix
- Aim for 90%+ test coverage on new code
- Run `bundle exec rspec` before submitting PR

---

## Documentation Guidelines

- Update relevant docs if your change affects users (README, USER_GUIDE, etc.)
- Add examples for new features
- Use ATX-style headers (`#`, `##`, `###`)
- Use code fences with language specification

See **[Code Style](DEVELOPER_GUIDE.md#code-style)** for comment guidelines.

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>: <description>

feat:     # New feature
fix:      # Bug fix
docs:     # Documentation only
test:     # Adding/updating tests
refactor: # Code refactoring
chore:    # Maintenance

# Examples:
git commit -m "feat: add reminder date support"
git commit -m "fix: escape quotes in CSV titles properly"
git commit -m "docs: add API examples to user guide"
```

---

## Community

### Communication Channels

- **GitHub Issues** - Bug reports, feature requests
- **GitHub Discussions** - Questions, ideas, general chat
- **Pull Requests** - Code review and discussion

### Getting Help

**Stuck on something?**

1. Check [User Guide](USER_GUIDE.md) and [Developer Guide](DEVELOPER_GUIDE.md)
2. Search [existing issues](https://github.com/scurry/export-ms-todo/issues)
3. Ask in [Discussions](https://github.com/scurry/export-ms-todo/discussions)
4. Tag @scurry in a comment

### Becoming a Maintainer

Active contributors may be invited to become maintainers. Maintainers:
- Review pull requests
- Triage issues
- Help with releases
- Guide project direction

---

## Recognition

Contributors are recognized in:
- **README.md** acknowledgments section
- **CHANGELOG.md** release notes
- GitHub contributor graph

---

## Quick Reference

### Common Commands

| Task | Command |
|------|---------|
| Setup | `bundle install` |
| Run tests | `bundle exec rspec` |
| Run CLI | `bundle exec bin/export-ms-todo export` |
| Create branch | `git checkout -b feature/my-feature` |

See **[Developer Guide](DEVELOPER_GUIDE.md)** for complete command reference, architecture details, and debugging tips.

---

## Questions?

- 📖 [Developer Guide](DEVELOPER_GUIDE.md) - Architecture, testing, debugging
- 💬 [Discussions](https://github.com/scurry/export-ms-todo/discussions) - Ask questions
- 🐛 [Issues](https://github.com/scurry/export-ms-todo/issues) - Report bugs

---

**Thank you for contributing! 🙏**

Every contribution, no matter how small, makes Export MS Todo better for everyone.

**[← Developer Guide](DEVELOPER_GUIDE.md)** | **[Back to README](../README.md)**
