# Building with XcodeBuildMCP

Complete reference for building iOS, macOS apps and Swift packages using XcodeBuildMCP tools.

---

## Building iOS Simulator Apps

### Command

```javascript
mcp__XcodeBuildMCP__build_sim()
```

### When to Use

- Changed code in `Targets/ios-template-app/`
- Modified iOS-specific features
- Before testing on simulator
- After modifying UI components

### Session Defaults Required

- `workspacePath` or `projectPath`
- `scheme`
- `simulatorId` or `simulatorName`

### Example

```javascript
// Set defaults first
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17"
})

// Then build
mcp__XcodeBuildMCP__build_sim()
```

---

## Building macOS Apps

### Command

```javascript
mcp__XcodeBuildMCP__build_macos()
```

### When to Use

- Changed macOS app target code
- Modified macOS-specific features
- Before running macOS app
- After updating app delegate or window controller

### Session Defaults Required

- `workspacePath` or `projectPath`
- `scheme`

### Example

```javascript
// Set defaults
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "macOS-app"
})

// Build
mcp__XcodeBuildMCP__build_macos()
```

---

## Building Swift Packages

### Command

```javascript
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core"
})
```

### When to Use

- Changed code in SPM packages (Common/Core, Common/DesignSystem, Features/*)
- Modified Package.swift
- Before running package tests
- After adding new source files to package

### Parameters

**Required:**
- `packagePath`: Path to Package.swift directory

**Optional:**
- `configuration`: `"debug"` or `"release"` (default: `"debug"`)
- `architectures`: Array of architectures (e.g., `["arm64", "x86_64"]`)
- `preferXcodebuild`: `true` to use xcodebuild instead of swift build

### Examples

**Build Core package:**
```javascript
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core"
})
```

**Build with release configuration:**
```javascript
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core",
    configuration: "release"
})
```

**Build feature package:**
```javascript
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Features/Login"
})
```

**Build for iOS (when package contains UIKit):**
```javascript
// Use preferXcodebuild for iOS-specific packages
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core",
    preferXcodebuild: true
})
```

---

## Build Workflow

### Standard Build Cycle

```
1. Make code changes
   ↓
2. Build via XcodeBuildMCP
   ↓
3. Fix compilation errors
   ↓
4. Build again
   ↓
5. BUILD SUCCESS ✅
   ↓
6. Proceed to testing
```

### Example: Complete Build Workflow

```
Agent modifies LoginViewModel.swift

1. mcp__XcodeBuildMCP__swift_package_build({
     packagePath: "ios-template-app/Features/Login"
   })

   → BUILD FAILED: Missing import

2. Add: import Core

3. mcp__XcodeBuildMCP__swift_package_build({
     packagePath: "ios-template-app/Features/Login"
   })

   → BUILD SUCCESS ✅

4. Continue with testing
```

---

## Build Options

### Debug vs Release

**Debug (default):**
- Includes debug symbols
- Faster build times
- No optimizations
- Use for development and testing

**Release:**
- Optimized for performance
- Slower build times
- Use for production builds

```javascript
// Debug build (default)
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core"
})

// Release build
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core",
    configuration: "release"
})
```

### Clean Before Build

If you encounter caching issues:

```javascript
// Clean first
mcp__XcodeBuildMCP__clean()

// Then build
mcp__XcodeBuildMCP__build_sim()
```

---

## Build Errors

### Common Build Failures

**1. Missing imports**
```
error: cannot find 'SomeType' in scope
```
**Fix:** Add import statement

**2. Type mismatch**
```
error: cannot convert value of type 'X' to expected argument type 'Y'
```
**Fix:** Check type conformance or add type casting

**3. Missing files**
```
error: no such file or directory
```
**Fix:** Verify file exists and is added to target

**4. Package dependency issues**
```
error: no such module 'PackageName'
```
**Fix:**
- Check Package.swift dependencies
- Run `xcodegen generate` if package was recently added
- Verify package builds independently

### Build Error Workflow

```
BUILD FAILED
   ↓
Read error message
   ↓
Identify issue
   ↓
Fix code
   ↓
Build again
   ↓
Repeat until SUCCESS
```

**IMPORTANT:** Fix build errors autonomously. Don't ask user for help with compilation issues.

---

## Build Output

### Success Output

```
✅ Build succeeded for scheme ios-template-app
Build time: 5.2 seconds
```

### Failure Output

```
❌ Build failed for scheme ios-template-app

Errors:
/path/to/file.swift:42:10: error: cannot find 'foo' in scope
```

---

## Platform-Specific Considerations

### iOS Packages with UIKit

**Problem:** `swift_package_build` defaults to macOS, but package uses UIKit

**Solution:** Ensure Package.swift specifies iOS platform only:

```swift
platforms: [
    .iOS(.v26)  // iOS only, no .macOS
],
```

If package must support both, use `preferXcodebuild: true`:

```javascript
mcp__XcodeBuildMCP__swift_package_build({
    packagePath: "ios-template-app/Common/Core",
    preferXcodebuild: true
})
```

### macOS-Specific Code

For macOS-only packages, Platform.swift might use `#if os(macOS)` guards.

---

## Related

- `testing.md` - Running tests after building
- `session-management.md` - Setting up session defaults
- `troubleshooting.md` - Solving build problems

---

**Last Updated**: 2026-01-15
