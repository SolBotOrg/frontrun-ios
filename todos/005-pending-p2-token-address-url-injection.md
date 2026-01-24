---
status: pending
priority: p2
issue_id: "005"
tags: [code-review, security, pr-15]
dependencies: []
---

# Missing Token Address Validation Before URL Construction

## Problem Statement

The `getExplorerUrl()` function constructs URLs by directly interpolating the `address` field without sanitization. While `ChainDetection.isValidTokenAddress()` exists, it is not enforced before URL generation.

## Findings

**File:** `Frontrun/FRModels/Sources/DexTokenInfo.swift`
**Lines:** 49-76

```swift
public func getExplorerUrl() -> String? {
    let addr = self.address  // No validation!
    switch chainId.lowercased() {
    case "ethereum", "eth":
        return "https://etherscan.io/token/\(addr)"  // Direct interpolation
    // ...
    default:
        return "https://dexscreener.com/\(chainId)/\(addr)"  // chainId also unvalidated
    }
}
```

**Impact:**
- URL path injection could redirect users to malicious pages
- Special characters in addresses could break URL parsing
- `chainId` is also directly interpolated without validation

## Proposed Solutions

### Option 1: URL-Encode Parameters (Recommended)
- **Pros:** Prevents injection, simple fix
- **Cons:** None
- **Effort:** Small (30 minutes)
- **Risk:** Very Low

```swift
public func getExplorerUrl() -> String? {
    guard ChainDetection.isValidTokenAddress(address) else { return nil }
    guard let encodedAddr = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
    // ... use encodedAddr in URL construction
}
```

## Recommended Action

**Option 1** - Add address validation and URL encoding.

## Acceptance Criteria

- [x] Token addresses are validated before URL construction
- [x] URL parameters are properly encoded
- [x] Invalid addresses return nil URL

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Security agent flagged injection risk |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
