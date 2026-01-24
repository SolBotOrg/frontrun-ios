---
status: pending
priority: p3
issue_id: "010"
tags: [code-review, quality, refactoring, pr-15]
dependencies: []
---

# God Method: parseResponse is 92 Lines

## Problem Statement

The `parseResponse` method in `DexScreenerService` handles too many responsibilities: JSON deserialization, nested property extractions, type coercion, and fallback logic.

## Findings

**File:** `Frontrun/FRServices/Sources/DexScreenerService.swift`
**Lines:** 138-230 (92 lines)

The method contains:
- JSON parsing
- 4 repeated type coercion patterns (Double vs String)
- 3 different image URL extraction attempts
- Error handling

**Duplicate pattern (appears 4 times):**
```swift
if let h24 = priceChange["h24"] as? Double {
    priceChange24h = h24
} else if let h24String = priceChange["h24"] as? String, let h24 = Double(h24String) {
    priceChange24h = h24
}
```

## Proposed Solutions

### Option 1: Extract Helper Methods
- **Pros:** Better readability, DRY
- **Cons:** More methods
- **Effort:** Small (1-2 hours)
- **Risk:** Very Low

```swift
private func extractDoubleValue(_ dict: [String: Any], key: String) -> Double? {
    if let value = dict[key] as? Double { return value }
    if let str = dict[key] as? String { return Double(str) }
    return nil
}
```

### Option 2: Use Codable
- **Pros:** Type-safe, compiler-optimized
- **Cons:** More model definitions
- **Effort:** Medium (3-4 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Extract duplicate patterns to helper methods.

## Acceptance Criteria

- [ ] `parseResponse` is under 50 lines
- [ ] Duplicate type coercion extracted
- [ ] Functionality unchanged

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Pattern agent found code duplication |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
