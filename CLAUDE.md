# CLAUDE.md

Main router for Claude Code in this repository. Read specialized documentation on-demand.

---

## Project type

**iOS app, Swift, SwiftUI.** Confirmed by the user on 2026-04-18. Default to SwiftUI for all new UI; only drop to UIKit when SwiftUI genuinely can't do the job (e.g. specific `UIViewControllerRepresentable` bridges).

## Repository status

Greenfield. No Xcode project, `Package.swift`, or source files have been created yet — only this file, `README.md`, `.gitignore`, and `.claude/` configuration. When the first Xcode project is scaffolded, update this file with build/run/test commands.

## Conventions

- Repo directory name contains a triple hyphen: `KKSW---first-app`. Preserve it exactly — don't "fix" it in paths or configs.

---

## Project Rules

**XcodeGen (when introduced):**
- Edit `project.yml`, then run `xcodegen generate`
- Never edit `.xcodeproj` manually
- Details: `.claude/guides/xcodegen/GUIDE.md`

**Build & Test:**
- Use **XcodeBuildMCP** tools for all Apple-platform build / run / test / simulator actions — preferred over plain `xcodebuild` shell invocations.
- Before the first build in a session, call `session_show_defaults` to verify project, scheme, and simulator.
- Fix compilation errors autonomously — don't ask the user for routine build failures.
- Details: `.claude/guides/xcodebuild-mcp/GUIDE.md`

**Adding new guides:**
- Follow `.claude/guides/create-new-guide/GUIDE.md`

---

## Token Efficiency

- For simple checks ("does X exist?", "find files of type Y") → use Glob/Grep directly, NOT Explore agent
- Explore agent only for open-ended questions requiring multiple rounds of search
- One focused question per agent — never bundle 5+ questions into a single Explore call
- Prefer targeted tools (Glob, Grep, Read) over broad agents for known file patterns

---

## Quick Reference

| Need | Location |
|------|----------|
| XcodeGen setup | `.claude/guides/xcodegen/GUIDE.md` |
| Build & test with XcodeBuildMCP | `.claude/guides/xcodebuild-mcp/GUIDE.md` |
| Authoring new guides | `.claude/guides/create-new-guide/GUIDE.md` |

---

**Last Updated**: 2026-04-18
