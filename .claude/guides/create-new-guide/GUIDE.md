---
summary: How to structure and organize guides for consistency
read_when: Before creating or refactoring guides
complexity: simple
status: active
last_updated: 2026-01-15
---

# Guide Structure Standardization

This is a meta-guide about how to write guides.

---

## Purpose

**Why standardize guides:**
- Consistent structure makes guides easier to find information
- Router pattern reduces cognitive load
- References allow deep-dives without cluttering main guide
- Agents can navigate documentation more efficiently

---

## Two Guide Patterns

### Pattern 1: Simple Guide (Single File)

**When to use:**
- Topic is narrow and focused
- Content fits in < 300 lines
- No need for separate deep-dives

**Structure:**
```markdown
---
summary: One-line description
read_when: When to read this
complexity: simple | medium | advanced
status: active | draft | deprecated
last_updated: YYYY-MM-DD
---

# Guide Title

## What is X?
Brief introduction

## How to Use X
Step-by-step instructions

## Examples
Practical examples

## Common Issues
Troubleshooting

## Related
Links to other guides
```

**Example:** `.claude/guides/swift-concurrency/GUIDE.md`

---

### Pattern 2: Router + References (Multi-File)

**When to use:**
- Topic is broad with multiple subtopics
- Content would exceed 300 lines in single file
- Need separate sections for different use cases
- Multiple reference documents needed

**Structure:**
```
guide-name/
├── GUIDE.md (router)
└── references/
    ├── subtopic-1.md
    ├── subtopic-2.md
    ├── subtopic-3.md
    └── troubleshooting.md
```

**Example:** `.claude/guides/testing/` or `.claude/guides/xcodebuild-mcp/`

---

## Router Pattern (GUIDE.md)

The main GUIDE.md acts as a **navigation hub**, not a content dump.

### Router Structure

```markdown
---
summary: One-line description
read_when: When to read this
complexity: medium
status: active
last_updated: YYYY-MM-DD
---

# Topic Name

This guide is a **router** to [Topic] specialized documentation.

---

## What is [Topic]?
Brief 2-3 paragraph introduction

## Quick Navigation

### 🎯 What are you doing?

**Use Case 1**
→ Read `references/subtopic-1.md`
- Bullet points of what's covered

**Use Case 2**
→ Read `references/subtopic-2.md`
- Bullet points of what's covered

## Decision Tree

```
Visual decision tree showing
    │
    ├─ Option A?
    │   └─ Read: references/file-a.md
    │
    └─ Option B?
        └─ Read: references/file-b.md
```

## Quick Start
Minimal example to get started fast

## References
Links to all reference docs with descriptions

## Related
Links to other guides/workflows/agents
```

### Router Examples

**Good routers:**
- `.claude/guides/testing/GUIDE.md`
- `.claude/guides/xcodebuild-mcp/GUIDE.md`

**What routers should NOT do:**
- ❌ Contain all content inline
- ❌ Duplicate reference content
- ❌ Exceed 300 lines

---

## Reference Documents (references/)

Reference documents contain **detailed, focused content** on one subtopic.

### Reference Structure

```markdown
# Subtopic Title

Complete reference for [specific subtopic].

---

## Section 1: Core Concepts

Deep explanation

---

## Section 2: How to Use

Step-by-step with examples

---

## Section 3: Advanced Usage

Complex scenarios

---

## Common Issues

Troubleshooting specific to this subtopic

---

## Related

Links to other references and guides

---

**Last Updated**: YYYY-MM-DD
```

### Reference Examples

**Good references:**
- `.claude/guides/testing/references/feature-flow.md`
- `.claude/guides/testing/references/isolated-logic.md`
- `.claude/guides/xcodebuild-mcp/references/building.md`
- `.claude/guides/xcodebuild-mcp/references/testing.md`

---

## File Naming

### Guide Directories

**Pattern:** `kebab-case`

```
✅ Good:
.claude/guides/testing/
.claude/guides/xcodebuild-mcp/
.claude/guides/swift-concurrency/

❌ Bad:
.claude/guides/TestingGuide/
.claude/guides/Xcode_Build/
.claude/guides/swift6/
```

### Reference Files

**Pattern:** `kebab-case.md`

```
✅ Good:
references/feature-flow.md
references/isolated-logic.md
references/session-management.md

❌ Bad:
references/FeatureFlow.md
references/isolated_logic.md
references/Session-Management.md
```

---

## When to Split a Guide

### Signs You Need Router + References

1. **Length:** GUIDE.md > 300 lines
2. **Subtopics:** More than 3 distinct subtopics
3. **Use Cases:** Multiple different use cases
4. **Depth:** Need both quick start AND deep-dives

### Migration Process

**From single file to router:**

```
1. Create references/ directory
2. Identify distinct subtopics
3. Extract each subtopic to references/subtopic.md
4. Rewrite GUIDE.md as router
5. Verify all links work
6. Update references to other guides
```

**Example migration:**

```
Before:
guides/
└── testing/
    └── GUIDE.md (800 lines - too long!)

After:
guides/
└── testing/
    ├── GUIDE.md (250 lines - router)
    └── references/
        ├── feature-flow.md
        ├── isolated-logic.md
        ├── best-practices.md
        └── anti-patterns.md
```

---

## Frontmatter Standards

All GUIDE.md files must have frontmatter:

```yaml
---
summary: One-line description (max 80 chars)
read_when: When agent should read this guide
complexity: simple | medium | advanced
status: active | draft | deprecated
last_updated: YYYY-MM-DD
---
```

**Field descriptions:**

- `summary`: Concise description for guide lists
- `read_when`: Helps agents decide when to read
- `complexity`: Helps agents prioritize
- `status`: Lifecycle state
- `last_updated`: Maintenance tracking

**Reference files:** Can optionally have minimal frontmatter or just date

---

## Agent Workflow (Token Efficiency)

Agents use frontmatter `read_when` field to decide WHEN to read each guide:

```
Agent sees task: "Create login view"
→ Checks guides/README.md
→ Finds view/GUIDE.md (read_when: "Creating new SwiftUI view")
→ Agent knows: "I need this guide!"
→ Reads full GUIDE.md
→ Follows steps
```

**Without frontmatter:**
- Agent reads ALL guides → wastes tokens

**With frontmatter:**
- Agent reads ONLY relevant guides → efficient

**Key fields for agents:**
- `read_when` - Most important! Tells agent when guide is needed
- `complexity` - Helps prioritize (simple guides first)
- `status` - Skip deprecated guides

---

## Content Guidelines

### Writing Style

**Do:**
- ✅ Use clear, concise language
- ✅ Provide examples for every concept
- ✅ Use decision trees for complex choices
- ✅ Include troubleshooting sections
- ✅ Link to related content

**Don't:**
- ❌ Use vague language ("might", "maybe", "possibly")
- ❌ Skip examples
- ❌ Assume prior knowledge
- ❌ Duplicate content across files

### Code Examples

**Format:**
```language
// Clear comments explaining what this does
code example here
```

**Include:**
- Language identifier
- Comments for complex parts
- Expected output when relevant

### Decision Trees

**Format:**
```
What are you trying to do?
    │
    ├─ Option A?
    │   └─ Read: file-a.md
    │
    └─ Option B?
        └─ Read: file-b.md
```

**Benefits:**
- Visual clarity
- Quick navigation
- Reduces cognitive load

---

## Testing Guide Structure

After creating or refactoring a guide, verify:

### ✅ Checklist

**Structure:**
- [ ] Frontmatter present and complete
- [ ] Router is < 300 lines (if using router pattern)
- [ ] References are focused and single-topic
- [ ] Decision tree helps navigate
- [ ] Quick start section exists

**Content:**
- [ ] Every concept has example
- [ ] Common issues documented
- [ ] Related guides linked
- [ ] Last updated date is current

**Links:**
- [ ] All internal links work
- [ ] All reference links work
- [ ] Related guide links work

---

## Examples to Study

### Excellent Routers

1. **`.claude/guides/testing/GUIDE.md`**
   - Clear navigation sections
   - Decision tree
   - Well-organized references

2. **`.claude/guides/xcodebuild-mcp/GUIDE.md`**
   - Concise introduction
   - Use case based navigation
   - Table of tools

### Excellent References

1. **`.claude/guides/testing/references/anti-patterns.md`**
   - Focused on one topic (what NOT to do)
   - Examples of bad vs good
   - Clear explanations

2. **`.claude/guides/xcodebuild-mcp/references/building.md`**
   - Comprehensive but focused
   - Organized by platform
   - Examples for each command

---

## Template Files

### Router Template

```markdown
---
summary: Brief description
read_when: When to use
complexity: medium
status: active
last_updated: YYYY-MM-DD
---

# Title

This guide is a **router** to [Topic] specialized documentation.

---

## What is [Topic]?

Brief introduction

---

## Quick Navigation

### 🎯 What are you doing?

**Use Case 1**
→ Read `references/subtopic-1.md`

---

## Decision Tree

```
Decision flow here
```

---

## Quick Start

Minimal example

---

## References

List of all references

---

## Related

Related guides
```

### Reference Template

```markdown
# Subtopic Title

Complete reference for [subtopic].

---

## Core Concepts

Explanation

---

## How to Use

Step-by-step

---

## Examples

Practical examples

---

## Common Issues

Troubleshooting

---

## Related

Links

---

**Last Updated**: YYYY-MM-DD
```

---

## Refactoring Existing Guides

### Priority Order

**High priority** (refactor first):
1. Guides > 500 lines
2. Guides with multiple distinct topics
3. Frequently referenced guides

**Medium priority:**
4. Guides 300-500 lines
5. Guides with growing content

**Low priority:**
6. Guides < 300 lines
7. Single-topic focused guides

### Refactoring Steps

1. **Analyze current guide**
   - Identify distinct subtopics
   - Count lines
   - Check usage frequency

2. **Plan structure**
   - List subtopics for references/
   - Design decision tree
   - Plan router navigation

3. **Create references/**
   - One subtopic per file
   - Keep focus tight
   - Include examples

4. **Rewrite router**
   - < 300 lines
   - Clear navigation
   - Decision tree
   - Quick start

5. **Update links**
   - Fix internal references
   - Update external links
   - Verify all work

6. **Document changes**
   - Update last_updated
   - Note in changelog if major

---

## Related

**Guides that follow this pattern:**
- `.claude/guides/testing/` - Excellent router example
- `.claude/guides/xcodebuild-mcp/` - Recently refactored
- `.claude/guides/spm-packages/` - Candidate for refactoring

**Improvements needed:**
- Create IMP-XXX for guides needing refactoring
- Document migration process
- Add automated structure validation

---

**Last Updated**: 2026-01-15
