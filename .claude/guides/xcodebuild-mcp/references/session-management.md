# Session Management

Complete reference for managing XcodeBuildMCP session defaults.

---

## What Are Session Defaults?

Session defaults store configuration that applies to all XcodeBuildMCP commands during a session. Instead of passing parameters to every command, set them once and reuse.

**Persistent hint:** `xcode-session.json` (in guide root) stores last used simulator/scheme across sessions. Check it before calling `list_sims` to speed up setup.

**Benefits:**
- Less repetition
- Consistent configuration
- Cleaner command calls

---

## Setting Session Defaults

### Command

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17",
    useLatestOS: true
})
```

### Common Parameters

**Project/Workspace:**
- `workspacePath`: Path to `.xcworkspace` file
- `projectPath`: Path to `.xcodeproj` file (alternative to workspacePath)

**Scheme:**
- `scheme`: Xcode scheme name (e.g., `"ios-template-app"`)

**Configuration:**
- `configuration`: Build configuration (`"Debug"` or `"Release"`)

**Simulator:**
- `simulatorName`: Simulator name (e.g., `"iPhone 17"`)
- `simulatorId`: Simulator UDID (alternative to simulatorName)
- `useLatestOS`: Use latest OS version (default: `true`)

**Device:**
- `deviceId`: Physical device UDID

**Architecture:**
- `arch`: Target architecture (`"arm64"` or `"x86_64"`)

**Other:**
- `suppressWarnings`: Filter warnings from build output to conserve context

---

## Examples

### iOS Simulator Setup

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17",
    useLatestOS: true
})
```

### macOS Setup

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "macOS-app"
})
```

### Physical Device Setup

```javascript
// First list devices
mcp__XcodeBuildMCP__list_devices()

// Then set device ID
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    deviceId: "00008110-001234567890001E"
})
```

### Debug vs Release

```javascript
// Debug (default)
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    configuration: "Debug"
})

// Release
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    configuration: "Release"
})
```

---

## Viewing Current Defaults

### Command

```javascript
mcp__XcodeBuildMCP__session_show_defaults()
```

### Example Output

```json
{
  "workspacePath": "ios-template-app.xcworkspace",
  "scheme": "ios-template-app",
  "simulatorId": "1271AE8E-8911-4E6C-B4AD-C185885EF1F9",
  "useLatestOS": true
}
```

---

## Clearing Session Defaults

### Clear All Defaults

```javascript
mcp__XcodeBuildMCP__session_clear_defaults({
    all: true
})
```

### Clear Specific Defaults

```javascript
mcp__XcodeBuildMCP__session_clear_defaults({
    keys: ["scheme", "simulatorName"]
})
```

### Available Keys

- `projectPath`
- `workspacePath`
- `scheme`
- `configuration`
- `simulatorName`
- `simulatorId`
- `deviceId`
- `useLatestOS`
- `arch`

---

## When to Set Defaults

### At Session Start

Set defaults once at the beginning of a session:

```
Session starts
   ↓
Set session defaults
   ↓
Work on tasks
   ↓
Session ends
```

### When Switching Targets

Change defaults when switching between different targets:

```
Working on iOS app
   ↓
mcp__XcodeBuildMCP__session_set_defaults({
    scheme: "ios-template-app",
    simulatorName: "iPhone 17"
})
   ↓
Build/Test iOS app
   ↓
Switch to macOS app
   ↓
mcp__XcodeBuildMCP__session_set_defaults({
    scheme: "macOS-app"
})
   ↓
Build/Test macOS app
```

---

## Which Tools Require Session Defaults?

### Require Session Defaults

**iOS Simulator:**
- `build_sim`
- `test_sim`
- `build_run_sim`

**macOS:**
- `build_macos`
- `test_macos`
- `build_run_macos`

**Device:**
- `build_device`
- `test_device`

### Don't Require Session Defaults

**Swift Packages:**
- `swift_package_build` (uses `packagePath` parameter)
- `swift_package_test` (uses `packagePath` parameter)

**Listing:**
- `list_sims`
- `list_devices`
- `list_schemes`

---

## Common Workflow

### Standard Setup

```javascript
// 1. Set defaults once
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17",
    useLatestOS: true
})

// 2. Use tools without repeating parameters
mcp__XcodeBuildMCP__build_sim()
mcp__XcodeBuildMCP__test_sim()

// 3. Build and test multiple times (defaults persist)
mcp__XcodeBuildMCP__build_sim()
mcp__XcodeBuildMCP__test_sim()
```

---

## Finding Simulator Names/IDs

### List Available Simulators

```javascript
mcp__XcodeBuildMCP__list_sims()
```

### Example Output

```
Available iOS Simulators:

com.apple.CoreSimulator.SimRuntime.iOS-26-1:
- iPhone 17 Pro (5C1021FD-76DC-4BC2-87F9-D181C51986D6)
- iPhone 17 (1271AE8E-8911-4E6C-B4AD-C185885EF1F9) [Booted]
- iPad Pro 13-inch (M5) (B7263D13-CE15-417E-9D38-5A1F0F7B1B25)
```

### Use Name or ID

```javascript
// Option 1: Use name
mcp__XcodeBuildMCP__session_set_defaults({
    simulatorName: "iPhone 17"
})

// Option 2: Use ID
mcp__XcodeBuildMCP__session_set_defaults({
    simulatorId: "1271AE8E-8911-4E6C-B4AD-C185885EF1F9"
})
```

---

## Finding Device IDs

### List Connected Devices

```javascript
mcp__XcodeBuildMCP__list_devices()
```

### Example Output

```
Connected Devices:

iOS Devices:
- John's iPhone (00008110-001234567890001E) [Connected]
- Test iPad (00008103-000987654321002F) [Connected]
```

### Set Device ID

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    deviceId: "00008110-001234567890001E"
})
```

---

## Troubleshooting

### Error: Session Defaults Not Set

```
Error: workspacePath not set in session defaults
```

**Solution:**
```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app"
})
```

### Error: Simulator Not Found

```
Error: Simulator "iPhone 16" not found
```

**Solution:**
1. List available simulators
2. Use exact name from list

```javascript
mcp__XcodeBuildMCP__list_sims()
// Use exact name shown
mcp__XcodeBuildMCP__session_set_defaults({
    simulatorName: "iPhone 17"  // Not "iPhone 16"
})
```

### Error: Scheme Not Found

```
Error: Scheme "ios-app" not found
```

**Solution:**
1. List available schemes
2. Use exact scheme name

```javascript
mcp__XcodeBuildMCP__list_schemes()
// Use exact scheme name
mcp__XcodeBuildMCP__session_set_defaults({
    scheme: "ios-template-app"  // Not "ios-app"
})
```

---

## Related

- `building.md` - Using defaults for building
- `testing.md` - Using defaults for testing
- `troubleshooting.md` - Solving session issues

---

**Last Updated**: 2026-03-20
