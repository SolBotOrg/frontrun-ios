---
status: pending
priority: p2
issue_id: "003"
tags: [code-review, performance, memory, pr-15]
dependencies: []
---

# Unbounded Cache Growth in DexScreenerService

## Problem Statement

The token info cache in `DexScreenerService` has no size limit or expiration mechanism. Over time, this could lead to excessive memory usage and stale data.

## Findings

**File:** `Frontrun/FRServices/Sources/DexScreenerService.swift`
**Lines:** 10-11

```swift
private var cache: [String: DexTokenInfo] = [:]
private var pendingRequests: [String: Signal<DexTokenInfo?, NoError>] = [:]
```

**Impact:**
- At 10,000 unique token lookups: ~4MB memory consumption
- At 100,000 unique token lookups: ~40MB memory consumption
- Stale data remains indefinitely (prices change frequently)
- Potential memory pressure on long-running sessions

## Proposed Solutions

### Option 1: Use NSCache (Recommended)
- **Pros:** Automatic memory management, system-aware eviction
- **Cons:** Need wrapper class for value types
- **Effort:** Small (1-2 hours)
- **Risk:** Very Low

```swift
private let cache = NSCache<NSString, DexTokenInfoWrapper>()

init() {
    cache.countLimit = 1000
    cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
}
```

### Option 2: LRU Cache with TTL
- **Pros:** More control, TTL for staleness
- **Cons:** More implementation work
- **Effort:** Medium (3-4 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Use `NSCache` for automatic memory management.

## Acceptance Criteria

- [ ] Cache has a maximum entry count (e.g., 1000)
- [ ] Cache entries expire or are evicted under memory pressure
- [ ] Token fetching still works correctly

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Performance agent flagged unbounded growth |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
