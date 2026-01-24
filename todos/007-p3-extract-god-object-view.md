---
id: "007"
priority: P3
status: open
category: architecture
file: Frontrun/FRSummaryUI/Sources/Components/SummaryContentComponent.swift
created: 2026-01-24
source: code-review
---

# Consider Extracting SummaryContentComponent.View Responsibilities

## Problem

`SummaryContentComponent.View` at ~800 lines handles multiple responsibilities:
- Text processing (token tags, user tags, markdown)
- Avatar loading and caching
- Token info fetching and caching
- Token logo loading
- Layout and scroll management

This is a "God object" pattern that could be split for better maintainability.

## Risk Level

LOW - This is a code quality improvement, not a functional issue.

## Suggested Extraction

Consider extracting:
1. `FRTextProcessor` - handles tag processing and markdown
2. `FRAvatarCache` - avatar loading and caching
3. `FRTokenInfoCache` - token info fetching and caching

## Trade-offs

**Pros:**
- Easier to test individual components
- Clearer responsibilities
- Easier to modify one aspect without affecting others

**Cons:**
- More files to manage
- May add complexity for small gains
- Current code works and is contained in one module

## Action

Consider for future refactoring if the component grows or needs modification. Not urgent.
