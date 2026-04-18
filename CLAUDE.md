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

**Architecture:**
- Clean Architecture: MVVM (Presentation) + UseCase (Domain) + Repository (Data).
- Apply SOLID, KISS, DRY — no layer or abstraction without a concrete reason; prefer iOS-native design patterns (Observer, Factory, Decorator, Strategy) over bespoke ones.
- ViewModels use `@Observable` and never import SwiftUI.
- Details: `.claude/guides/architecture/GUIDE.md`

**Navigation:**
- State-driven navigation via [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation) (`SwiftUINavigation`). Single `Destination?` enum on the ViewModel, `@CasePathable`, case-path bindings for sheets / alerts / stack paths.
- Details: `.claude/guides/navigation/GUIDE.md`

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

**Research context:**
- Curated product research lives in `.claude/research/` — Screen Time API / klon Opala, AI on-device, rynek. Index: `.claude/research/README.md`.
- Read relevant raport before proposing architecture or API decisions on touched topics.

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
| Architecture (MVVM / UseCase / Repository) | `.claude/guides/architecture/GUIDE.md` |
| Navigation (swift-navigation) | `.claude/guides/navigation/GUIDE.md` |
| XcodeGen setup | `.claude/guides/xcodegen/GUIDE.md` |
| Build & test with XcodeBuildMCP | `.claude/guides/xcodebuild-mcp/GUIDE.md` |
| Authoring new guides | `.claude/guides/create-new-guide/GUIDE.md` |
| Product / API research index | `.claude/research/README.md` |

---

**Last Updated**: 2026-04-18

<!-- GSD:project-start source:PROJECT.md -->
## Project

**DeluluDetox**

A native iOS self-control app that blocks distracting apps, categories, and websites on-demand or on schedule. A functional clone of Opal, built for adults who want to reclaim focus — not parental control, not Family Sharing. Everything on-device, no backend.

**Core Value:** **User can block chosen apps immediately and the block holds until the timer ends.** If nothing else works, this must. A focus blocker that can be trivially bypassed is worthless.

### Constraints

- **Tech stack**: Swift 6.2, SwiftUI, iOS 26.0+ — locked
- **No backend**: Everything on-device + App Group in MVP
- **Entitlement**: Requires Apple approval per bundle ID (2–3 week median)
- **Extension RAM**: DeviceActivityMonitor limited to 6 MB
- **Shield API**: Frozen since 2022, 8-field struct, no SwiftUI/network/TextField
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

Technology stack not yet documented. Will populate after codebase mapping or first phase.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
