---
status: pending
priority: p3
issue_id: "011"
tags: [code-review, simplification, yagni, pr-15]
dependencies: []
---

# YAGNI: 200-Line getContextSize() Function

## Problem Statement

The `getContextSize()` function is 198 lines of hardcoded model context sizes that will be outdated immediately. This is a maintenance nightmare, and the code already handles context overflow gracefully.

## Findings

**File:** `Frontrun/FRServices/Sources/AIConfiguration.swift`
**Lines:** 272-470 (198 lines!)

The function attempts to predict context limits for ~30 models across 6 providers. Model specifications change frequently, and this will require constant updates.

The code at lines 496-505 already handles context overflow by truncating messages, making this prediction less critical.

## Proposed Solutions

### Option 1: Remove Entirely (Recommended)
- **Pros:** -200 LOC, eliminates maintenance burden
- **Cons:** Less accurate initial truncation
- **Effort:** Small (30 minutes)
- **Risk:** Low - API returns clear error for context overflow

### Option 2: Use Simple Dictionary
- **Pros:** Easier to maintain
- **Cons:** Still requires updates
- **Effort:** Small (1 hour)
- **Risk:** Very Low

### Option 3: Fetch from API
- **Pros:** Always accurate
- **Cons:** Additional API call
- **Effort:** Medium (4 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Remove the function and rely on API errors for context overflow. The truncation logic at lines 496-505 can use a conservative default (e.g., 8192 tokens).

## Acceptance Criteria

- [ ] `getContextSize()` removed or significantly simplified
- [ ] Context overflow still handled gracefully
- [ ] AI summarization works correctly

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Simplicity agent flagged YAGNI violation |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
