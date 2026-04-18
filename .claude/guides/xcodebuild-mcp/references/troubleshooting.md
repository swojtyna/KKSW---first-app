# XcodeBuildMCP Troubleshooting

Common issues and solutions when running tests with XcodeBuildMCP.

---

## swift_package_test fails with "no such module 'UIKit'"

### Problem

Package contains UIKit code, but `swift_package_test` tries to build for macOS by default.

**Error message:**
```
error: no such module 'UIKit'
 1 | import UIKit
   |        `- error: no such module 'UIKit'
```

### Solution

**1. Check Package.swift platforms:**

```swift
// ❌ BAD - macOS listed for UIKit package
platforms: [
    .iOS(.v26),
    .macOS(.v10_15)  // ← Remove this!
],
```

```swift
// ✅ GOOD - iOS only for UIKit package
platforms: [
    .iOS(.v26)
],
```

**2. Edit Package.swift:**
- Remove `.macOS` platform
- Ensure iOS version is `.v26` (project supports iOS 26+)

**3. Run swift_package_test again:**

```javascript
swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    configuration: "debug"
})
```

### Why This Happens

- `swift_package_test` defaults to macOS when no destination specified
- UIKit is iOS-only framework
- Package must declare iOS-only platform

---

## Test target not found or cannot build

### Problem

Tests fail with "target not found" or "cannot code sign".

**Error message:**
```
error: Cannot code sign because the target does not have an Info.plist file
```

### Solution

**For app test targets:**

1. Check `project.yml`:
```yaml
ios-template-appTests:
  type: bundle.unit-test
  platform: iOS
  settings:
    base:
      GENERATE_INFOPLIST_FILE: YES  # ← Add this
  dependencies:
    - target: ios-template-app
    - package: Core  # ← If testing Core
```

2. Regenerate project:
```bash
xcodegen generate
```

3. Run tests again:
```javascript
test_sim({ scheme: "ios-template-app" })
```

**For package tests:**

Use `swift_package_test`, not `test_sim`:
```javascript
swift_package_test({
    packagePath: "path/to/package"
})
```

---

## Tests are in wrong location

### Problem

Created tests in `ios-template-appTests/Core/` but they should be in `Common/Core/Tests/CoreTests/`.

### Solution

**1. Identify correct location:**

```bash
# Find where code lives
find . -name "DIContainer.swift" -not -path "*/Tests/*"
# Result: ios-template-app/Common/Core/Sources/DependencyInjection/DIContainer.swift

# Tests should be in same module
# Correct: ios-template-app/Common/Core/Tests/CoreTests/DIContainerTests.swift
# Wrong:   ios-template-appTests/Core/DIContainerTests.swift
```

**2. Move test file:**

```bash
# Remove incorrect location
rm ios-template-appTests/Core/DIContainerTests.swift

# Edit or create in correct location
# ios-template-app/Common/Core/Tests/CoreTests/DIContainerTests.swift
```

**3. Run correct test command:**

For package:
```javascript
swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

**See:** `.claude/guides/testing/references/anti-patterns.md` section "Don't Put Module Tests in App Test Target"

---

## Session defaults not set

### Problem

`test_sim` fails because session defaults not configured.

**Error message:**
```
Error: No scheme specified
```

### Solution

**Set session defaults:**

```javascript
session_set_defaults({
    projectPath: "/path/to/project.xcodeproj",
    scheme: "ios-template-app",
    simulatorId: "UUID",
    useLatestOS: true
})
```

**Then run tests:**

```javascript
test_sim()
```

---

## Simulator not booted

### Problem

Tests fail because simulator isn't running.

### Solution

**1. List available simulators:**

```javascript
list_sims()
```

**2. Boot simulator:**

```javascript
boot_sim()  // Uses default from session
```

**3. Run tests:**

```javascript
test_sim()
```

---

## Package structure issues

### Problem

Package tests can't find test target or dependencies.

### Solution

**Verify Package.swift structure:**

```swift
let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        )
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],  // ← Must depend on Core
            path: "Tests/CoreTests"
        )
    ]
)
```

**Check test directory exists:**

```bash
ls -la ios-template-app/Common/Core/Tests/CoreTests/
```

---

## Swift concurrency issues

### Problem

Tests fail with data race warnings or MainActor errors.

**Error message:**
```
error: sending 'variable' risks causing data races
```

### Solution

**Mark tests with @MainActor:**

```swift
@Test("Test name") @MainActor
func testFunction() {
    // Test code accessing @MainActor isolated code
}
```

**Why:**
- DIContainer uses `MainActor.assumeIsolated`
- Tests capturing variables in @MainActor closures need @MainActor
- Swift 6 strict concurrency is enabled

**Mark entire suite as serialized if using shared state:**

```swift
@Suite("Suite Name", .serialized)
struct TestSuite {
    // Tests run sequentially
}
```

---

## General Troubleshooting Steps

1. **Read error message carefully**
   - Error messages usually point to exact problem

2. **Check Package.swift**
   - Platforms correct? (`.iOS(.v26)` for iOS)
   - Test target defined?
   - Dependencies declared?

3. **Verify file locations**
   - Is test in correct module?
   - Does Tests/ directory exist?

4. **Check guides**
   - `.claude/guides/testing/GUIDE.md`
   - `.claude/guides/testing/references/anti-patterns.md`

5. **Ask user if stuck**
   - Don't create workarounds
   - Don't copy tests to wrong locations
   - Ask for help

---

## Quick Reference

### Run package tests:
```javascript
swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

### Run app tests:
```javascript
test_sim({ scheme: "ios-template-app" })
```

### Check package structure:
```bash
# Package layout should be:
Common/Core/
├── Package.swift
├── Sources/
│   └── [source files]
└── Tests/
    └── CoreTests/
        └── [test files]
```

### Verify test location:
```bash
# Find code
find . -name "Component.swift" -not -path "*/Tests/*"

# Tests go in same module's Tests/ directory
```

---

**Last Updated**: 2026-01-14
