---
id: "006"
priority: P3
status: open
category: security
file: Frontrun/FRSummaryUI/Sources/Components/SummaryContentComponent.swift
created: 2026-01-24
source: code-review
---

# Validate AI-Generated Content Before Display

## Problem

AI-generated summary content is displayed without sanitization. While the text view is not executing scripts, malicious content could potentially:
- Display misleading token information
- Include phishing-like content
- Contain inappropriate material

## Risk Level

LOW - Content is displayed in a non-executable context, but validation improves robustness.

## Action

Consider adding content validation:
1. Verify token addresses in `<token>` tags match valid formats
2. Strip any HTML/script tags from AI response
3. Limit content length to prevent DoS

## Suggested Approach

```swift
private func sanitizeAIContent(_ content: String) -> String {
    // Remove any HTML-like tags except our custom <token> tags
    var sanitized = content
    // Keep <token> and </token> tags, remove others
    let htmlTagPattern = "<(?!/?token)[^>]+>"
    sanitized = sanitized.replacingOccurrences(
        of: htmlTagPattern,
        with: "",
        options: .regularExpression
    )
    // Truncate if extremely long
    if sanitized.count > 50000 {
        sanitized = String(sanitized.prefix(50000)) + "..."
    }
    return sanitized
}
```

## Verification

Test with edge case AI responses containing HTML/script tags.
