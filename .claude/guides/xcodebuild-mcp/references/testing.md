# Testing with XcodeBuildMCP

Complete reference for running tests on iOS simulator, macOS, and Swift packages using XcodeBuildMCP tools.

---

## iOS Simulator Tests

### Command

```javascript
mcp__XcodeBuildMCP__test_sim()
```

### When to Use

- Added new tests
- Changed business logic
- Modified ViewModels, Services, or Repositories
- Before completing task
- After fixing bugs

### Session Defaults Required

- `workspacePath` or `projectPath`
- `scheme`
- `simulatorId` or `simulatorName`
- `useLatestOS` (optional, default: true)

### Example

```javascript
// Set defaults first
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "ios-template-app",
    simulatorName: "iPhone 17",
    useLatestOS: true
})

// Run tests
mcp__XcodeBuildMCP__test_sim()
```

### What Gets Tested

- App target tests (`ios-template-appTests/`)
- UI tests (`ios-template-appUITests/`)
- **Package tests** (e.g., `CoreTests`) if added to scheme

---

## macOS Tests

### Command

```javascript
mcp__XcodeBuildMCP__test_macos()
```

### When to Use

- Added macOS-specific tests
- Changed macOS app logic
- Testing macOS app target

### Session Defaults Required

- `workspacePath` or `projectPath`
- `scheme`

### Example

```javascript
mcp__XcodeBuildMCP__session_set_defaults({
    workspacePath: "ios-template-app.xcworkspace",
    scheme: "macOS-app"
})

mcp__XcodeBuildMCP__test_macos()
```

---

## Swift Package Tests

### Command

```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

### When to Use

- Added tests to SPM package
- Changed package logic
- Testing Core/DesignSystem utilities
- Testing isolated logic (extensions, utilities)

### Parameters

**Required:**
- `packagePath`: Path to Package.swift directory

**Optional:**
- `configuration`: `"debug"` or `"release"` (default: `"debug"`)
- `filter`: Test name filter (regex pattern)
- `parallel`: Run tests in parallel (default: `true`)
- `showCodecov`: Show code coverage (default: `false`)
- `preferXcodebuild`: Use xcodebuild instead of swift test

### Examples

**Basic package test:**
```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

**Test with code coverage:**
```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    showCodecov: true
})
```

**Filter specific tests:**
```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    filter: "DIContainer.*"  // Only DIContainer tests
})
```

**Test in release mode:**
```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    configuration: "release"
})
```

---

## Test Workflow

### Standard Test Cycle

```
1. Implement code
   ↓
2. Build (verify compilation)
   ↓
3. Write tests
   ↓
4. Run tests via XcodeBuildMCP
   ↓
5. Fix test failures
   ↓
6. Run tests again
   ↓
7. ALL TESTS PASS ✅
   ↓
8. Move task to done
```

### Example: Complete Test Workflow

```
Agent creates LoginViewModel with tests

1. Create LoginViewModel.swift
2. Build package (verify no errors)
3. Create LoginViewModelTests.swift (23 tests)
4. mcp__XcodeBuildMCP__swift_package_test({
     packagePath: "ios-template-app/Features/Login"
   })

   → FAILED: 2 tests failed

5. Fix: Update assertion logic
6. mcp__XcodeBuildMCP__swift_package_test({
     packagePath: "ios-template-app/Features/Login"
   })

   → PASSED: 23/23 tests ✅

7. Task complete
```

---

## Test Output

### Success Output

```
✅ Test Run test succeeded for scheme ios-template-app

Test Summary: Test - ios-template-app
Overall Result: Passed

Test Counts:
  Total: 23
  Passed: 23
  Failed: 0
  Skipped: 0

Device: iPhone 17 (iOS Simulator 26.1)
```

### Failure Output

```
❌ Test Run test failed for scheme ios-template-app

Failed Tests:
- DIContainerTests.testResolve (CoreTests)
  Expected: "test-123"
  Got: "test-456"

Test Counts:
  Total: 23
  Passed: 22
  Failed: 1
```

---

## Test Failures

### Handling Test Failures

**Process:**
1. Read failure message carefully
2. Identify root cause
3. Fix implementation or test
4. Re-run tests
5. Repeat until all pass

**IMPORTANT:** Fix test failures autonomously. Don't ask user unless fundamentally unsure about business logic.

### Common Test Failures

**1. Assertion failure**
```
#expect failed: Expected true, got false
```
**Fix:** Check test logic or implementation

**2. Async timeout**
```
Test timed out after 30 seconds
```
**Fix:** Check for deadlocks or missing async/await

**3. Concurrency issues**
```
Data race detected
```
**Fix:** Add @MainActor or proper synchronization

**4. Missing mock data**
```
Fatal error: Unexpectedly found nil
```
**Fix:** Ensure mocks return valid data

---

## Test Types

### Unit Tests (Package Tests)

**Location:** `Common/Core/Tests/CoreTests/`

**What to test:**
- Pure logic
- Extensions
- Utilities
- Isolated components

**Use:** `swift_package_test`

```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

### Integration Tests (App Tests)

**Location:** `ios-template-appTests/`

**What to test:**
- Feature flows (ViewModel → UseCase → Repository)
- App-specific logic
- Integration between modules

**Use:** `test_sim`

```javascript
mcp__XcodeBuildMCP__test_sim()
```

### UI Tests

**Location:** `ios-template-appUITests/`

**What to test:**
- User interactions
- Navigation flows
- UI state changes

**Use:** `test_sim` (includes UI tests automatically)

---

## Test Coverage

### Viewing Coverage

```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    showCodecov: true
})
```

### Coverage Goals

- **Core utilities:** 90%+ coverage
- **Business logic:** 80%+ coverage
- **ViewModels:** 70%+ coverage
- **Views:** Not required (UI tests cover this)

---

## Parallel Testing

### Enable Parallel Execution

```javascript
// Default: parallel enabled
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    parallel: true
})
```

### When to Disable

- Tests use shared state (e.g., `DIContainer.shared`)
- Tests modify file system
- Tests use global mocks

```javascript
// Disable parallel for tests with shared state
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core",
    parallel: false
})
```

**NOTE:** Use `.serialized` trait in `@Suite` instead:

```swift
@Suite("DIContainer Tests", .serialized) @MainActor
struct DIContainerTests { }
```

---

## Package Tests vs App Tests

### When to Use Package Tests

- Testing Core utilities (extensions, helpers)
- Testing isolated logic
- Testing pure functions
- Fast feedback loop

```javascript
mcp__XcodeBuildMCP__swift_package_test({
    packagePath: "ios-template-app/Common/Core"
})
```

### When to Use App Tests

- Testing features end-to-end
- Testing app-specific logic
- Testing with real app dependencies

```javascript
mcp__XcodeBuildMCP__test_sim()
```

### Decision Tree

```
What are you testing?
    │
    ├─ Core package code?
    │   └─ Use swift_package_test
    │
    ├─ Feature package code?
    │   └─ Use swift_package_test
    │
    └─ App target code?
        └─ Use test_sim
```

---

## Test Environment Variables

### Passing Environment Variables

```javascript
mcp__XcodeBuildMCP__test_sim({
    testRunnerEnv: {
        "USE_MOCK_API": "true",
        "API_BASE_URL": "http://localhost:8080"
    }
})
```

Variables are automatically prefixed with `TEST_RUNNER_`.

---

## Simulator Management

### List Available Simulators

```javascript
mcp__XcodeBuildMCP__list_sims()
```

### Boot Simulator

```javascript
mcp__XcodeBuildMCP__boot_sim()
```

### Common Simulators

- `"iPhone 17"` - Latest iPhone
- `"iPhone 17 Pro"` - Pro model
- `"iPad Pro 13-inch (M5)"` - Latest iPad

---

## Related

- `building.md` - Building before testing
- `session-management.md` - Setting up session defaults
- `troubleshooting.md` - Solving test problems
- `.claude/guides/testing/GUIDE.md` - Writing tests

---

**Last Updated**: 2026-01-15
