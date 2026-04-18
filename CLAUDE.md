# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project type

**iOS app, Swift, SwiftUI.** Confirmed by the user on 2026-04-18. Default to SwiftUI for all new UI; only drop to UIKit when SwiftUI genuinely can't do the job (e.g. specific `UIViewControllerRepresentable` bridges).

## Repository status

Greenfield. No Xcode project, `Package.swift`, or source files have been created yet — only this file, `README.md`, and `.gitignore`. When the first Xcode project is scaffolded, update this file with build/run/test commands.

## Tooling

- Use **XcodeBuildMCP** tools for all Apple-platform build / run / test / simulator actions — they are preferred over `xcodebuild` shell invocations.
- Before the first build in a session, call `session_show_defaults` to verify project, scheme, and simulator.

## Conventions

- Repo directory name contains a triple hyphen: `KKSW---first-app`. Preserve it exactly — don't "fix" it in paths or configs.
