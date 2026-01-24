---
id: "005"
priority: P2
status: resolved
category: security
file: Frontrun/FRSummaryUI/Sources/Views/TokenInfoActionSheet.swift
created: 2026-01-24
source: code-review
---

# Address URL Injection Risk in Fallback URL Construction

## Problem

The fallback URL construction concatenates user-controlled data (token address) without validation:

```swift
let explorerUrl = URL(string: "https://dexscreener.com/\(chain)/\(tokenInfo.tokenAddress)")
```

If `tokenInfo.tokenAddress` contains malicious characters, it could lead to URL manipulation.

## Risk Level

MEDIUM - The token address is typically validated by DexScreener API responses, but defensive coding is recommended.

## Action

1. URL-encode the token address before constructing the URL
2. Validate token address format (alphanumeric only for most chains)

## Suggested Fix

```swift
guard let encodedAddress = tokenInfo.tokenAddress.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
    return
}
let explorerUrl = URL(string: "https://dexscreener.com/\(chain)/\(encodedAddress)")
```

## Verification

Test with edge cases:
- Token address with special characters
- Empty token address
- Extremely long token address
