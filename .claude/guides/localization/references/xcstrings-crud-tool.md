# xcstrings-crud Tool

Complete reference for using xcstrings-crud to manage `.xcstrings` files programmatically.

---

## What is xcstrings-crud?

[xcstrings-crud](https://github.com/Ryu0118/xcstrings-crud) is a CLI tool and MCP server for managing String Catalog (`.xcstrings`) files programmatically. It enables adding, deleting, and listing localization keys without opening Xcode.

---

## Installation

The binary is pre-built and committed at `.ai/tools/bin/xcstrings-crud` **in the template app**. For this project, build from source if needed:

```bash
git clone https://github.com/Ryu0118/xcstrings-crud.git /tmp/xcstrings-crud
cd /tmp/xcstrings-crud && swift build -c release
# Copy to a local tools directory if desired
cp .build/release/xcstrings-crud /usr/local/bin/xcstrings-crud
```

---

## Available Commands

### Add a Key

```bash
xcstrings-crud add \
  --key "homeEmptyHeading" \
  --value "No enemies yet." \
  --language en \
  --file DeluluDetox/Resources/Localizable.xcstrings
```

Add translations for other languages:

```bash
xcstrings-crud add \
  --key "homeEmptyHeading" \
  --value "Jeszcze żadnych wrogów." \
  --language pl \
  --file DeluluDetox/Resources/Localizable.xcstrings

xcstrings-crud add \
  --key "homeEmptyHeading" \
  --value "Sin enemigos aún." \
  --language es \
  --file DeluluDetox/Resources/Localizable.xcstrings
```

### Delete a Key

```bash
xcstrings-crud delete \
  --key "oldDeprecatedKey" \
  --file DeluluDetox/Resources/Localizable.xcstrings
```

### List Keys

```bash
xcstrings-crud list \
  --file DeluluDetox/Resources/Localizable.xcstrings
```

---

## MCP Server Integration

xcstrings-crud can run as an MCP (Model Context Protocol) server, enabling AI agents to manage `.xcstrings` files directly.

### Configuration

Add to `~/.claude.json` under the project's `mcpServers` object:

```json
"xcstrings-crud": {
  "type": "stdio",
  "command": "/path/to/xcstrings-crud",
  "args": ["mcp"]
}
```

Also add `"mcp__xcstrings-crud__*"` to the `allow` list in `.claude/settings.local.json` so tools work without prompting.

### Agent Usage

With MCP integration, AI agents can:
- Add new localization keys during feature development
- Remove deprecated keys during cleanup
- List all keys for auditing or migration
- Check translation coverage across languages

---

## When to Use xcstrings-crud

| Scenario | Use xcstrings-crud? |
|----------|-------------------|
| Adding a few strings manually | No — use Xcode editor |
| Batch adding keys for a new feature | Yes — faster than manual entry |
| AI agent creating localized feature | Yes — via MCP integration |
| Removing deprecated keys in bulk | Yes — script with delete command |
| Auditing keys across features | Yes — list command |
| Translating strings | No — use Xcode or XLIFF workflow |

---

## Common Issues

- **File path**: Always use the path to `DeluluDetox/Resources/Localizable.xcstrings` (relative to repo root)
- **JSON validity**: xcstrings-crud modifies the JSON directly. If the file becomes invalid, open in Xcode to repair
- **Build after changes**: After modifying `.xcstrings` via CLI, build the project to pick up changes

---

## Related

- `string-catalogs-setup.md` - Understanding .xcstrings file format
- `key-naming-convention.md` - Keys must follow naming convention
- `export-import-workflow.md` - Alternative workflow for translators

---

**Last Updated**: 2026-04-26
