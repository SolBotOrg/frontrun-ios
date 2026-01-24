---
status: pending
priority: p2
issue_id: "004"
tags: [code-review, security, pr-15]
dependencies: []
---

# Missing URL Validation for Custom AI Endpoints

## Problem Statement

The `buildEndpointURL()` method accepts arbitrary URLs for custom AI endpoints without validation. This could allow API requests to internal network resources (SSRF risk) or non-HTTPS endpoints.

## Findings

**File:** `Frontrun/FRServices/Sources/AIConfiguration.swift`
**Lines:** 508-534

```swift
public func buildEndpointURL() -> String {
    var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

    // No validation of scheme or host!
    if url.hasSuffix("/") {
        url = String(url.dropLast())
    }
    // ... constructs URL without validating
}
```

**Impact:**
- API keys could be sent to attacker-controlled servers
- Could be used to probe internal network resources
- Non-HTTPS endpoints would send credentials in cleartext

## Proposed Solutions

### Option 1: Validate HTTPS and Block Private IPs (Recommended)
- **Pros:** Prevents SSRF and cleartext transmission
- **Cons:** May block legitimate internal testing setups
- **Effort:** Small (1-2 hours)
- **Risk:** Low

```swift
public func buildEndpointURL() -> String? {
    guard let url = URL(string: baseURL),
          url.scheme == "https" else {
        return nil // Only allow HTTPS
    }

    // Optionally block private IP ranges
    if let host = url.host, isPrivateIP(host) {
        return nil
    }

    // ... rest of URL building
}
```

## Recommended Action

**Option 1** - Require HTTPS scheme, optionally warn for private IPs.

## Acceptance Criteria

- [ ] Custom endpoints must use HTTPS
- [ ] Invalid URLs return nil or show error to user
- [ ] Default providers (OpenAI, Anthropic) still work

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Security agent flagged SSRF risk |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
