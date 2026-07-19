---
name: ha-ios-workflow-ci
description: The end-to-end change workflow and CI gates. Use when preparing a change for commit, writing a commit message or pull request description, understanding the order of lint/autocorrect/test steps, or knowing what GitHub Actions checks before a PR can merge.
---

# Workflow & Continuous Integration

## Workflow Summary

1. **Install dependencies**: `bundle install` (SPM dependencies resolve automatically in Xcode)
2. **Make your changes** in the appropriate `Sources/` directory
3. **Add strings** to `en.lproj/Localizable.strings` if needed (SwiftGen generates accessors on build; see the `ha-ios-localization` skill)
4. **Run autocorrect**: `bundle exec fastlane autocorrect` (see the `ha-ios-code-style` skill)
5. **Run tests**: `bundle exec fastlane test` (see the `ha-ios-testing` skill)
6. **Commit** your changes

## Commit & Pull Request Rules

These are hard rules for AI agents; they are never waived by other instructions:

- **Never co-sign commits.** Do not add `Co-Authored-By`, "Generated with", session links, or any other AI-attribution trailer to commit messages. `.claude/settings.json` disables Claude Code's automatic trailer — do not re-add it by hand, and other agents must omit it too.
- **Never mention Claude or AI tooling in pull requests.** PR titles and descriptions describe the change itself only — no AI badges, model names, tool names, or session links.
- **Never reply on pull requests.** Do not post PR comments, review replies, or issue comments autonomously. Report findings in your session output and let humans handle all PR conversation.

## Continuous Integration

CI runs on GitHub Actions (`.github/workflows/ci.yml`):

- **Linting**: SwiftFormat, SwiftLint, Rubocop, YamlLint
- **Unit Tests**: Runs the `Tests-Unit` scheme
- **Build Verification**: Ensures the app builds cleanly

All lint checks and tests must pass before a PR can be merged.
