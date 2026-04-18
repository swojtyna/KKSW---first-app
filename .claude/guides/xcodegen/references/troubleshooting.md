# XcodeGen Troubleshooting

Complete reference for common issues, pitfalls, and solutions when working with XcodeGen.

---

## Quick Fixes

### File not showing in Xcode

**Problem**: Added file, but not showing in Xcode.

**Solution**:
```bash
xcodegen generate
```

### Build errors after `git pull`

**Problem**: Build fails after pulling changes.

**Solution**:
```bash
xcodegen generate
```

### Merge conflict in `project.yml`

**Problem**: Git conflict in project.yml.

**Solution**:
1. Resolve YAML conflict (human-readable!)
2. Regenerate: `xcodegen generate`

---

## Common Pitfalls

### 1. Forgetting to Regenerate

**Problem**: Added file, but not showing in Xcode.

**Solution**: `xcodegen generate`

### 2. Editing .xcodeproj Manually

**Problem**: Changes lost on next regeneration.

**Solution**: Edit `project.yml` instead.

### 3. Committing .xcodeproj to Git

**Problem**: Merge conflicts, large diffs.

**Solution**: Add to `.gitignore`:
```
*.xcodeproj
*.xcworkspace
```

### 4. Not Using `createIntermediateGroups`

**Problem**: Flat structure in Xcode, hard to navigate.

**Solution**: Set `createIntermediateGroups: true`

### 5. Using `testTargets` with `testPlans`

**Problem**: SPM package tests not running.

**Solution**: Use ONLY `testPlans` in scheme, never both. See `spm-and-testing.md`.

### 6. Missing `fileGroups` for Test Plan

**Problem**: "test plan could not be read" error.

**Solution**: Add test plan to `fileGroups` in project.yml:
```yaml
fileGroups:
  - ios-template-app.xctestplan
```

### 7. SPM Package Tests Ignored

**Problem**: Test targets from SPM packages don't appear in test navigator.

**Solution**: Create workspace with packages as root. See `spm-and-testing.md`.

---

## Error Messages

### "test plan could not be read"

**Cause**: Test plan not registered in project.

**Fix**: Add to `fileGroups`:
```yaml
fileGroups:
  - ios-template-app.xctestplan
```

### "Unable to find build target"

**Cause**: Target name mismatch or missing regeneration.

**Fix**:
1. Verify target name in `project.yml`
2. `xcodegen generate`

### "Missing required module"

**Cause**: Dependency not configured.

**Fix**: Add dependency in `project.yml`:
```yaml
targets:
  MyTarget:
    dependencies:
      - package: MissingModule
```
Then regenerate.

---

## Golden Rules

1. ✅ `project.yml` is source of truth
2. ✅ Use `createIntermediateGroups: true`
3. ✅ Regenerate after structural changes
4. ✅ Commit `project.yml`, NOT `.xcodeproj`
5. ✅ Use cache for faster regeneration
6. ❌ NEVER edit `.xcodeproj` manually
7. ❌ NEVER commit `.xcodeproj` to git

---

## Debugging Steps

When something doesn't work:

1. **Regenerate**: `xcodegen generate`
2. **Check YAML syntax**: Use YAML validator
3. **Verify paths**: Ensure all paths in `project.yml` exist on disk
4. **Clean derived data**: `rm -rf ~/Library/Developer/Xcode/DerivedData`
5. **Check Xcode version**: Some features require specific Xcode versions

---

## Related

- `basics.md` - XcodeGen fundamentals
- `configuration.md` - Advanced configuration options
- `spm-and-testing.md` - SPM packages and test setup

---

**Last Updated**: 2026-01-19
