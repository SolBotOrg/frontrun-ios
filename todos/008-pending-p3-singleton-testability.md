---
status: pending
priority: p3
issue_id: "008"
tags: [code-review, architecture, testing, pr-15]
dependencies: []
---

# Singletons Prevent Unit Testing

## Problem Statement

`DexScreenerService.shared` and `AIConfigurationStorage.shared` use private init, making it impossible to inject mocks for unit testing. The protocols exist but cannot be leveraged.

## Findings

**File:** `Frontrun/FRServices/Sources/DexScreenerService.swift`
```swift
public final class DexScreenerService: DexScreenerServiceProtocol {
    public static let shared = DexScreenerService()
    private init() {}  // Cannot create test instances
}
```

**File:** `Frontrun/FRServices/Sources/AIConfiguration.swift`
```swift
public final class AIConfigurationStorage {
    public static let shared = AIConfigurationStorage()
    private init() {}  // No protocol defined
}
```

**Impact:**
- Cannot mock services in unit tests
- Protocols exist but are not useful for testing
- Tight coupling between UI and services

## Proposed Solutions

### Option 1: Add Internal Init for Testing
- **Pros:** Maintains singleton convenience, enables testing
- **Cons:** Requires `@testable import` for tests
- **Effort:** Small (30 minutes)
- **Risk:** Very Low

```swift
public final class DexScreenerService: DexScreenerServiceProtocol {
    public static let shared = DexScreenerService()

    // Internal for testing
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
}
```

### Option 2: Dependency Injection Container
- **Pros:** Full DI support, best for testability
- **Cons:** More refactoring needed
- **Effort:** Large (8+ hours)
- **Risk:** Medium

## Recommended Action

**Option 1** - Add internal init to allow test injection.

## Acceptance Criteria

- [ ] Services can be instantiated in tests
- [ ] Singleton pattern still works for production
- [ ] Add protocol for AIConfigurationStorage

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Architecture agent flagged testability |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
