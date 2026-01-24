---
status: pending
priority: p3
issue_id: "009"
tags: [code-review, performance, pr-15]
dependencies: []
---

# Regex Compiled on Every Token Estimation Call

## Problem Statement

The `estimateTokenCount` function compiles a regex pattern on every call, which is expensive (~1ms per compilation).

## Findings

**File:** `Frontrun/FRServices/Sources/AIConfiguration.swift`
**Lines:** 474-478

```swift
public static func estimateTokenCount(for text: String) -> Int {
    let chinesePattern = "[\\u4e00-\\u9fff]"
    let chineseRegex = try? NSRegularExpression(pattern: chinesePattern, options: [])
    // ... used for counting Chinese characters
}
```

**Impact:**
- ~1ms overhead per call
- Called repeatedly during message truncation calculations
- Unnecessary CPU usage

## Proposed Solutions

### Option 1: Cache Static Regex (Recommended)
- **Pros:** 10-100x faster, trivial fix
- **Cons:** None
- **Effort:** Small (10 minutes)
- **Risk:** Very Low

```swift
private static let chineseRegex: NSRegularExpression? = {
    try? NSRegularExpression(pattern: "[\\u4e00-\\u9fff]", options: [])
}()

public static func estimateTokenCount(for text: String) -> Int {
    let chineseCount = chineseRegex?.numberOfMatches(
        in: text,
        options: [],
        range: NSRange(text.startIndex..., in: text)
    ) ?? 0
    // ...
}
```

## Recommended Action

**Option 1** - Cache the compiled regex at static level.

## Acceptance Criteria

- [ ] Regex is compiled once at static initialization
- [ ] Token estimation performance improved
- [ ] Functionality unchanged

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Performance agent flagged repeated compilation |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
