# XcodeGen Configuration

Complete reference for project.yml configuration: options, splitting configs, setting groups, schemes, performance.

---

## Project Organization

### Best Practice: Split Large Configs

For complex projects, split `project.yml` into multiple files:

```yaml
# project.yml
name: MyProject

include:
  - base-config.yml
  - targets/app-targets.yml
  - targets/framework-targets.yml

options:
  bundleIdPrefix: com.example
```

```yaml
# base-config.yml
options:
  deploymentTarget:
    iOS: "26.0"
  createIntermediateGroups: true
  transitivelyLinkDependencies: true

settingGroups:
  common_settings:
    SWIFT_VERSION: "5.10"
    DEVELOPMENT_TEAM: ABC123
```

```yaml
# targets/app-targets.yml
targets:
  MainApp:
    type: application
    platform: iOS
    sources: [MainApp]
    settings:
      groups: [common_settings]
```

**When to split?**
- ✅ Project has 5+ targets
- ✅ Shared build settings across targets
- ✅ Team works on separate modules
- ❌ Simple projects (1-3 targets) - keep single file

---

## Essential Options

### Recommended `options` for Most Projects:

```yaml
options:
  # Auto-generate bundle IDs
  bundleIdPrefix: com.yourcompany

  # Deployment targets
  deploymentTarget:
    iOS: "26.0"

  # Group organization - CRITICAL for matching disk structure
  createIntermediateGroups: true
  generateEmptyDirectories: false

  # Xcode formatting
  usesTabs: false
  indentWidth: 2
  tabWidth: 2

  # Default configuration
  defaultConfig: Debug

  # Development language
  developmentLanguage: en
```

---

## `createIntermediateGroups: true`

**What it does:**
Creates groups in Xcode for each folder level.

**Example:**
```
Disk: ios-template-app/Common/Core/Sources/File.swift

true  → Xcode: ios-template-app → Common → Core → Sources → File.swift
false → Xcode: Sources → File.swift
```

**Recommendation**: `true` (Xcode structure = disk structure)

---

## Setting Groups (DRY Build Settings)

Avoid repeating build settings across targets:

```yaml
settingGroups:
  release_settings:
    SWIFT_OPTIMIZATION_LEVEL: "-O"
    ENABLE_TESTABILITY: "NO"

  debug_settings:
    SWIFT_OPTIMIZATION_LEVEL: "-Onone"
    ENABLE_TESTABILITY: "YES"

targets:
  MyApp:
    settings:
      groups: [release_settings]
      configs:
        Debug:
          groups: [debug_settings]
```

---

## File Type Overrides

Apply compiler flags to specific file types:

```yaml
options:
  fileTypes:
    swift:
      compilerFlags: ["-warn-long-function-bodies"]
```

---

## Custom Schemes

Define build, run, test, and archive actions:

```yaml
schemes:
  MyApp:
    build:
      targets:
        MyApp: all
    run:
      config: Debug
      commandLineArguments:
        "-com.apple.CoreData.SQLDebug": 1
    test:
      config: Debug
      targets:
        - MyAppTests
```

For SPM package tests, see `spm-and-testing.md` for the `testPlans` approach.

---

## Performance Tips

### 1. Use Caching

```bash
# First generation
xcodegen generate

# Subsequent generations (skips if unchanged)
xcodegen generate --use-cache
```

**When to use cache?**
- ✅ Daily development (faster regeneration)
- ❌ After `git pull` (might miss changes)
- ❌ CI/CD pipelines (always regenerate fresh)

### 2. Suppress Output in CI

```bash
xcodegen generate --quiet
```

---

## Target Organization

### Framework vs SPM Package?

| Aspect | SPM Package (local) | XcodeGen Framework |
|--------|---------------------|-------------------|
| **Structure in Xcode** | Always in "Packages" | Can match folder structure |
| **Compilation** | Separate | Part of project |
| **Testability** | Requires export | Direct access |
| **Portability** | Can reuse in other projects | Project-specific |
| **Best for** | Shared utilities | App modules |

### Example: XcodeGen Framework (if you want "Common" structure):

```yaml
targets:
  Core:
    type: framework
    platform: iOS
    deploymentTarget: "26.0"
    sources:
      - path: ios-template-app/Common/Core/Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.core

  CoreTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: ios-template-app/Common/Core/Tests
    dependencies:
      - target: Core
```

**Benefit**: Core shows under "Common" folder in Xcode, not "Packages".

---

## Related

- `basics.md` - XcodeGen fundamentals
- `spm-and-testing.md` - SPM packages and test setup
- `troubleshooting.md` - Common issues and solutions

---

**Last Updated**: 2026-01-19
