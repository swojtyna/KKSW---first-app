---
summary: XcodeGen project generation from project.yml
read_when: Before modifying project structure, adding targets/packages, running SPM tests
complexity: medium
status: active
last_updated: 2026-01-19
---

# XcodeGen Guide

This guide is a **router** to XcodeGen specialized documentation.

---

## What is XcodeGen?

XcodeGen generates `.xcodeproj` files from a human-readable `project.yml` specification.

**Core principle:** `project.yml` is the source of truth. `.xcodeproj` is auto-generated.

**Benefits:**
- Eliminates merge conflicts in `.xcodeproj`
- Human-readable YAML instead of XML
- Automatic folder → group synchronization
- Perfect for CI/CD pipelines

---

## Quick Navigation

### 🎯 What are you doing?

**Starting with XcodeGen / Adding files or targets**
→ Read `references/basics.md`
- Quick reference commands
- Common tasks (add file, target, dependency)
- Daily workflow

**Configuring project options / Optimizing project.yml**
→ Read `references/configuration.md`
- Essential options (createIntermediateGroups, etc.)
- Splitting large configs
- Setting groups (DRY)
- Custom schemes
- Performance tips

**Setting up SPM package tests**
→ Read `references/spm-and-testing.md`
- Local/remote SPM packages
- **Critical:** Running SPM package tests (workspace, fileGroups, testPlans)
- Anti-patterns to avoid

**Something not working?**
→ Read `references/troubleshooting.md`
- Common pitfalls
- Error messages
- Golden rules

---

## Decision Tree

```
What are you doing?
    │
    ├─ New to XcodeGen / Basic tasks?
    │   └─ Read: references/basics.md
    │
    ├─ Configuring project options?
    │   └─ Read: references/configuration.md
    │
    ├─ Setting up SPM packages?
    │   │
    │   ├─ Just adding dependency?
    │   │   └─ Read: references/basics.md (Add Dependency section)
    │   │
    │   └─ Need to run package tests?
    │       └─ Read: references/spm-and-testing.md (CRITICAL)
    │
    └─ Something broken?
        └─ Read: references/troubleshooting.md
```

---

## Quick Start

### Generate Project

```bash
xcodegen generate
```

### Add File (no YAML edit needed)

```bash
touch ios-template-app/Targets/ios-template-app/NewFile.swift
xcodegen generate
```

### Add SPM Package

```yaml
# project.yml
packages:
  Core:
    path: ios-template-app/Common/Core

targets:
  ios-template-app:
    dependencies:
      - package: Core
```

```bash
xcodegen generate
```

### Quick Reference Table

| Task | Action |
|------|--------|
| **Generate project** | `xcodegen generate` |
| **Add new file** | Create file → regenerate |
| **Add target/dependency** | Edit `project.yml` → regenerate |
| **Faster regeneration** | `xcodegen generate --use-cache` |

---

## Golden Rules

1. ✅ `project.yml` is source of truth
2. ✅ Use `createIntermediateGroups: true`
3. ✅ Regenerate after structural changes
4. ✅ Commit `project.yml`, NOT `.xcodeproj`
5. ❌ NEVER edit `.xcodeproj` manually
6. ❌ NEVER commit `.xcodeproj` to git

---

## References

| Reference | Description |
|-----------|-------------|
| `references/basics.md` | Fundamentals, common tasks, workflow |
| `references/configuration.md` | Options, splitting configs, schemes, performance |
| `references/spm-and-testing.md` | SPM packages, **running package tests** |
| `references/troubleshooting.md` | Common issues, error messages, solutions |

---

## Related

**Guides:**
- `xcodebuild-mcp/` - Building and testing with XcodeBuildMCP
- `spm-packages/` - Swift Package Manager packages
- `testing/` - Unit and UI tests

**Resources:**
- [XcodeGen Official Docs](https://github.com/yonaskolb/XcodeGen)
- [ProjectSpec Reference](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- Context7: `/yonaskolb/xcodegen`

---

**Last Updated**: 2026-01-19
