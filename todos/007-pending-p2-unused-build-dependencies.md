---
status: pending
priority: p2
issue_id: "007"
tags: [code-review, architecture, pr-15]
dependencies: []
---

# Unused Dependencies in BUILD Files

## Problem Statement

The new Bazel BUILD files include dependencies that are not actually used in the code, increasing build time and coupling.

## Findings

**File 1:** `Frontrun/FRModels/BUILD`
```python
deps = [
    "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",  # NOT USED
],
```
`DexTokenInfo.swift` only uses `Foundation` - no Signal-related code.

**File 2:** `Frontrun/FRServices/BUILD`
```python
deps = [
    "//submodules/Postbox:Postbox",  # NOT USED
],
```
No FRServices file imports Postbox.

**Impact:**
- Unnecessary build dependencies
- Slower incremental builds
- False coupling between modules

## Proposed Solutions

### Option 1: Remove Unused Dependencies (Recommended)
- **Pros:** Cleaner builds, accurate dependency graph
- **Cons:** None
- **Effort:** Small (10 minutes)
- **Risk:** Very Low

```python
# FRModels/BUILD - remove SwiftSignalKit
swift_library(
    name = "FRModels",
    deps = [],  # Pure Foundation
)

# FRServices/BUILD - remove Postbox
swift_library(
    name = "FRServices",
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//Frontrun/FRModels:FRModels",
    ],
)
```

## Recommended Action

**Option 1** - Remove unused dependencies from both BUILD files.

## Acceptance Criteria

- [x] FRModels/BUILD has no SwiftSignalKit dependency
- [x] FRServices/BUILD has no Postbox dependency
- [x] Build still succeeds

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Architecture agent verified with grep |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
