---
status: pending
priority: p2
issue_id: "006"
tags: [code-review, quality, pr-15]
dependencies: []
---

# Print Statements Not Wrapped in DEBUG Guard

## Problem Statement

`DexScreenerService` uses `print()` statements that will appear in release builds, potentially leaking user data (token addresses) and implementation details.

## Findings

**File:** `Frontrun/FRServices/Sources/DexScreenerService.swift`
**Lines:** 101, 114, 124

```swift
print("[DexScreener] Network error for \(address): \(error.localizedDescription)")
print("[DexScreener] HTTP error \(httpResponse.statusCode) for \(address)")
print("[DexScreener] Parse error for \(address): \(error)")
```

In contrast, `AIService.swift` correctly uses `#if DEBUG`:
```swift
#if DEBUG
print("[AIService] Failed to parse JSON: \(jsonString.prefix(100))")
#endif
```

**Impact:**
- Token addresses logged in release builds (privacy concern)
- Error details could help attackers understand implementation

## Proposed Solutions

### Option 1: Wrap in #if DEBUG (Recommended)
- **Pros:** Simple, consistent with AIService pattern
- **Cons:** Logs not available in production for debugging
- **Effort:** Small (15 minutes)
- **Risk:** Very Low

### Option 2: Use Proper Logging Framework
- **Pros:** Configurable log levels, structured logging
- **Cons:** Additional dependency or setup
- **Effort:** Medium (2-3 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Wrap all print statements in `#if DEBUG` guards.

## Acceptance Criteria

- [ ] All print statements wrapped in `#if DEBUG`
- [ ] No user data logged in release builds
- [ ] Debug logging still works in development

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Pattern agent found inconsistency |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
