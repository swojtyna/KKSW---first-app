# XcodeGen Basics

Complete reference for XcodeGen fundamentals: installation, project generation, common tasks.

---

## Quick Reference

| Task | Action |
|------|--------|
| **Generate project** | `xcodegen generate` |
| **Add new file** | Create file → regenerate |
| **Add target/dependency** | Edit `project.yml` → regenerate |
| **Faster regeneration** | `xcodegen generate --use-cache` |

---

## Core Principle

**`project.yml` is the source of truth. `.xcodeproj` is auto-generated.**

- ✅ Edit `project.yml` for project structure
- ✅ Create files/folders normally
- ✅ Regenerate to update `.xcodeproj`
- ❌ **NEVER** edit `.xcodeproj` manually
- ❌ **NEVER** commit `.xcodeproj` to git

**Why XcodeGen?**
- Eliminates merge conflicts in `.xcodeproj`
- Human-readable YAML instead of XML
- Automatic folder → group synchronization
- Perfect for CI/CD pipelines

---

## Common Tasks

### 1. Add New Swift File

**No special steps needed!**

```bash
# Create file
touch ios-template-app/Targets/ios-template-app/NewFile.swift

# Regenerate
xcodegen generate
```

XcodeGen auto-detects files based on `sources` paths in `project.yml`.

### 2. Add New Target

Edit `project.yml`:

```yaml
targets:
  NewModule:
    type: framework
    platform: iOS
    deploymentTarget: "26.0"
    sources:
      - path: ios-template-app/Common/NewModule/Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.yourcompany.newmodule
```

Regenerate: `xcodegen generate`

### 3. Add Dependency

**Between targets:**
```yaml
targets:
  ios-template-app:
    dependencies:
      - target: Core
```

**SPM package (local):**
```yaml
packages:
  Core:
    path: ios-template-app/Common/Core

targets:
  ios-template-app:
    dependencies:
      - package: Core
```

**SPM package (remote):**
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

Regenerate: `xcodegen generate`

### 4. Change Bundle ID

```yaml
options:
  bundleIdPrefix: com.newcompany
```

Or per-target:
```yaml
targets:
  ios-template-app:
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.custom.bundleid
```

### 5. Change iOS Deployment Target

```yaml
options:
  deploymentTarget:
    iOS: "27.0"
```

---

## Workflow

### Daily Development

1. Work normally (add files, edit code)
2. Regenerate **only when**:
   - Adding new target
   - Changing dependencies
   - Changing build settings
   - After `git pull` if `project.yml` changed

### After `git pull`

```bash
# Check if project.yml changed
git diff HEAD@{1} project.yml

# If yes → regenerate
xcodegen generate
```

### Before Commit

```bash
# Verify project.yml
xcodegen generate

# Stage ONLY project.yml
git add project.yml

# NEVER commit .xcodeproj
```

---

## Resources

- [XcodeGen Official Docs](https://github.com/yonaskolb/XcodeGen)
- [ProjectSpec Reference](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- Context7: `/yonaskolb/xcodegen`

---

## Related

- `configuration.md` - Advanced configuration options
- `spm-and-testing.md` - SPM packages and test setup
- `troubleshooting.md` - Common issues and solutions

---

**Last Updated**: 2026-01-19
