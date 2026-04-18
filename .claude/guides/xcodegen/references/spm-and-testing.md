# SPM Package Management & Testing

Complete reference for SPM packages with XcodeGen: local/remote packages, and **critical workarounds for running SPM package tests**.

---

## SPM Package Basics

### Local Packages

```yaml
packages:
  Core:
    path: ios-template-app/Common/Core

targets:
  ios-template-app:
    dependencies:
      - package: Core
```

**⚠️ Important**: SPM packages **ALWAYS** show in "Packages" group in Xcode, NOT in folder structure.

**Want folder structure in Xcode?** → Use XcodeGen frameworks instead (see `configuration.md`).

### Remote Packages

```yaml
packages:
  Alamofire:
    url: https://github.com/Alamofire/Alamofire
    from: 5.8.0

targets:
  ios-template-app:
    dependencies:
      - package: Alamofire
```

---

## Running SPM Package Tests

**Root Cause**: Xcode treats local SPM packages as "dependencies", not "root packages". Apple engineer Boris Buegling confirmed: *"You can only run tests of root packages, not dependencies."*

**Solution requires 3 elements:**

---

### 1. Workspace with packages as root

Create `ios-template-app.xcworkspace/contents.xcworkspacedata`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
   <FileRef location="group:ios-template-app.xcodeproj"/>
   <FileRef location="group:ios-template-app/Common/Core"/>
   <FileRef location="group:ios-template-app/Common/FeatureCommons"/>
   <FileRef location="group:ios-template-app/Features/Dashboard"/>
</Workspace>
```

This file survives `xcodegen generate` - commit it to git.

---

### 2. Register test plan in project (fileGroups)

In `project.yml`:

```yaml
name: ios-template-app

fileGroups:
  - ios-template-app.xctestplan  # ← REQUIRED

options:
  # ...
```

Without this, Xcode cannot read the test plan ("test plan could not be read" error).

---

### 3. Use testPlans in scheme (NOT testTargets)

In `project.yml` schemes section:

```yaml
schemes:
  ios-template-app:
    test:
      config: Debug
      testPlans:                              # ← Use testPlans
        - path: ios-template-app.xctestplan
          defaultPlan: true
    # ... other actions
```

**⚠️ Do NOT add `testTargets` to target's scheme** - it conflicts with `testPlans`.

---

### 4. Configure test plan correctly

`ios-template-app.xctestplan`:

```json
{
  "configurations" : [
    { "id" : "...", "name" : "Configuration 1", "options" : {} }
  ],
  "defaultOptions" : {
    "codeCoverage" : false,
    "targetForVariableExpansion" : {
      "containerPath" : "container:ios-template-app.xcodeproj",
      "identifier" : "E7A9933717E9445178C749D0",
      "name" : "ios-template-app"
    }
  },
  "testTargets" : [
    {
      "target" : {
        "containerPath" : "container:ios-template-app/Common/Core",
        "identifier" : "CoreTests",
        "name" : "CoreTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:ios-template-app/Common/FeatureCommons",
        "identifier" : "FeatureCommonsTests",
        "name" : "FeatureCommonsTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:ios-template-app/Features/Dashboard",
        "identifier" : "DashboardTests",
        "name" : "DashboardTests"
      }
    },
    {
      "parallelizable" : false,
      "target" : {
        "containerPath" : "container:ios-template-app.xcodeproj",
        "identifier" : "740BF769C653622AA83DD80A",
        "name" : "ios-template-appTests"
      }
    }
  ],
  "version" : 1
}
```

**Key differences for SPM vs xcodeproj targets:**

| Property | SPM Package | xcodeproj Target |
|----------|-------------|------------------|
| `containerPath` | `container:path/to/Package` | `container:Project.xcodeproj` |
| `identifier` | Test target name (e.g., `CoreTests`) | Blueprint ID (stable across regenerations) |

---

## Adding New SPM Package Tests

1. Create tests in `Package/Tests/PackageTests/`
2. Add package to workspace XML (`ios-template-app.xcworkspace/contents.xcworkspacedata`)
3. Add test target to `ios-template-app.xctestplan`
4. Run: `test_sim` via XcodeBuildMCP

---

## SPM Package Tests Anti-Patterns

| ❌ Don't | ✅ Do | Why |
|----------|-------|-----|
| Use `testTargets` in target's scheme | Use `testPlans` in schemes section | They conflict - scheme ignores test plan |
| Skip `fileGroups` for test plan | Add test plan to `fileGroups` | Test plan won't be registered in project |
| Use project without workspace | Create workspace with packages | Packages stay "dependencies", tests ignored |
| Remove `targetForVariableExpansion` | Keep it in test plan | Test plan becomes unreadable |
| Use `swift test` for UIKit packages | Use XcodeBuildMCP `test_sim` | UIKit not available on macOS |
| Expect XcodeGen to generate package test schemes | Create workspace manually | XcodeGen limitation ([Issue #983](https://github.com/yonaskolb/XcodeGen/issues/983)) |
| Simplify test plan format (name only) | Use full format with containerPath | Xcode can't resolve test targets |

---

## Sources

- [Swift Forums - SPM test limitation](https://forums.swift.org/t/cant-add-swiftpm-testtarget-to-xcode-test-plan/71260)
- [XcodeGen Issue #983](https://github.com/yonaskolb/XcodeGen/issues/983) - Test targets from SPM
- [XcodeGen Issue #1050](https://github.com/yonaskolb/XcodeGen/issues/1050) - Test plans

---

## Related

- `basics.md` - XcodeGen fundamentals
- `configuration.md` - Advanced configuration options
- `troubleshooting.md` - Common issues and solutions
- `../testing/GUIDE.md` - Testing guide

---

**Last Updated**: 2026-01-19
