---
summary: Using XcodeBuildMCP for building and testing iOS/macOS apps and SPM packages
read_when: When implementing tasks that modify code, need to verify builds, or run tests
complexity: medium
status: active
last_updated: 2026-01-15
---

# XcodeBuildMCP Usage Guide

This guide is a **router** to XcodeBuildMCP specialized documentation.

---

## What is XcodeBuildMCP?

XcodeBuildMCP is an MCP (Model Context Protocol) server that provides tools for building, testing, and managing Xcode projects and Swift packages without leaving the AI agent context.

**Why use XcodeBuildMCP:**
- Build verification directly from AI agent
- Run tests and capture results
- Autonomous error fixing during development
- No manual Xcode interaction needed

---

## Core Principles

1. **ALWAYS build after code changes** - Verify no compilation errors
2. **ALWAYS test after logic changes** - Ensure functionality works
3. **Fix errors autonomously** - Don't ask user for compilation issues
4. **Use appropriate tool for target** - iOS vs macOS vs SPM package

---

## Quick Navigation

### 🔨 What are you doing?

**Building code**
→ Read `references/building.md`
- iOS simulator builds
- macOS app builds
- Swift package builds
- Build workflow and error handling

**Running tests**
→ Read `references/testing.md`
- iOS simulator tests
- macOS tests
- Swift package tests
- Test workflow and failure handling

**Managing session**
→ Read `references/session-management.md`
- Setting session defaults
- Viewing current configuration
- Clearing defaults
- Finding simulators and devices

**Troubleshooting**
→ Read `references/troubleshooting.md`
- UIKit module errors
- Test target issues
- Platform version mismatches
- Session configuration problems

---

## Decision Tree

```
What do you need to do?
    │
    ├─ Build iOS app?
    │   └─ Read: references/building.md (iOS Simulator section)
    │
    ├─ Build macOS app?
    │   └─ Read: references/building.md (macOS section)
    │
    ├─ Build Swift package?
    │   └─ Read: references/building.md (Swift Packages section)
    │
    ├─ Run tests?
    │   └─ Read: references/testing.md
    │
    ├─ Set up session?
    │   └─ Read: references/session-management.md
    │
    └─ Fix build/test errors?
        └─ Read: references/troubleshooting.md
```

---

## Quick Start

### First Time Setup

**Session hint file:** `xcode-session.json` (in this directory) stores last used simulator/scheme. Check it before running `list_sims`.

1. **Set session defaults** (once per session)

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17",
    useLatestOS: true
})
```

See: `references/session-management.md`

2. **Build your target**

```javascript
// iOS app
mcp__XcodeBuildMCP__build_sim()

// macOS app
mcp__XcodeBuildMCP__build_macos()

// Swift package
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core"
})
```

See: `references/building.md`

3. **Run tests**

```javascript
// iOS app tests
mcp__XcodeBuildMCP__test_sim()

// macOS app tests
mcp__XcodeBuildMCP__test_macos()

// Swift package tests
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

See: `references/testing.md`

---

## Common Workflows

### iOS App Development

```
1. Set session defaults
   → references/session-management.md

2. Make code changes

3. Build app
   → mcp__XcodeBuildMCP__build_sim()
   → references/building.md

4. Fix compilation errors (autonomous)

5. Run tests
   → mcp__XcodeBuildMCP__test_sim()
   → references/testing.md

6. Fix test failures (autonomous)

7. All green ✅ → Task done
```

### Swift Package Development

```
1. Make code changes to package

2. Build package
   → mcp__XcodeBuildMCP__swift_package_build({
        packagePath: "ios-template-app/Common/Core"
      })
   → references/building.md

3. Fix compilation errors (autonomous)

4. Run package tests
   → mcp__XcodeBuildMCP__swift_package_test({
        packagePath: "ios-template-app/Common/Core"
      })
   → references/testing.md

5. Fix test failures (autonomous)

6. All green ✅ → Task done
```

---

## When to Use Which Tool?

### Building

| Target | Tool | Reference |
|--------|------|-----------|
| iOS app | `build_sim` | building.md |
| macOS app | `build_macos` | building.md |
| Swift package | `swift_package_build` | building.md |

### Testing

| Target | Tool | Reference |
|--------|------|-----------|
| iOS app | `test_sim` | testing.md |
| macOS app | `test_macos` | testing.md |
| Swift package | `swift_package_test` | testing.md |

### Session Management

| Task | Tool | Reference |
|------|------|-----------|
| Set defaults | `session_set_defaults` | session-management.md |
| View defaults | `session_show_defaults` | session-management.md |
| Clear defaults | `session_clear_defaults` | session-management.md |

---

## References

### Core Documentation

1. **[building.md](references/building.md)**
   - iOS, macOS, and Swift package builds
   - Build workflow and error handling
   - Platform-specific considerations
   - Clean builds

2. **[testing.md](references/testing.md)**
   - iOS simulator, macOS, and package tests
   - Test workflow and failure handling
   - Coverage and parallel execution
   - Test types (unit, integration, UI)

3. **[session-management.md](references/session-management.md)**
   - Setting and viewing session defaults
   - Simulator and device selection
   - Configuration management
   - Common workflows

4. **[troubleshooting.md](references/troubleshooting.md)**
   - UIKit module errors
   - Test target configuration issues
   - Platform version mismatches
   - Session setup problems

---

## Integration with Other Guides

### Related Guides

- **testing/GUIDE.md** - Writing tests that XcodeBuildMCP will run
- **spm-packages/GUIDE.md** - Creating packages that XcodeBuildMCP will build
- **swift-concurrency/GUIDE.md** - Concurrency patterns for tests

### Related Workflows

- **task-management** - XcodeBuildMCP is used in task verification and build-loop
  - See `references/build-loop.md` for autonomous error fixing

### Related Agents

- **builder** - Specialized agent using XcodeBuildMCP
- **qa** - Quality assurance using XcodeBuildMCP tests
- **developer-unittest** - Creates tests run by XcodeBuildMCP

---

## Important Notes

### Always Use XcodeBuildMCP (Not Direct Commands)

**❌ Don't do this:**
```bash
# DON'T use bash commands
xcodebuild test -scheme ios-template-app
swift test --package-path ios-template-app/Common/Core
```

**✅ Do this:**
```javascript
// Use XcodeBuildMCP tools
mcp__XcodeBuildMCP__test_sim()
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

**Why:**
- XcodeBuildMCP handles configuration automatically
- Proper error reporting and parsing
- Session management
- You're instructed to use it in system prompt

### Fix Errors Autonomously

- **Build errors**: Fix and rebuild (don't ask user)
- **Test failures**: Fix and rerun (don't ask user)
- **Configuration issues**: Consult troubleshooting guide

Only ask user if:
- Fundamentally unsure about business logic
- Multiple valid solutions exist
- Need clarification on requirements

---

**Last Updated**: 2026-03-20
