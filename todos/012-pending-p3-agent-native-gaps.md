---
status: pending
priority: p3
issue_id: "012"
tags: [code-review, architecture, agent-native, pr-15]
dependencies: []
---

# Agent-Native Architecture Gaps

## Problem Statement

The services in PR #15 are designed for UI consumption without explicit agent tooling. An external agent cannot invoke these services without writing Swift code.

## Findings

**Agent-Native Score: 4/12 capabilities agent-accessible**

| Capability | Status | Issue |
|------------|--------|-------|
| Fetch token info | Warning | Accessible but not documented |
| Generate chat summary | Critical | UI-only workflow, no agent equivalent |
| Get AI configuration | Warning | Accessible but not documented |
| Navigate to message | Critical | No agent equivalent |

**Missing:**
1. Agent tool registry for service discovery
2. Standalone `ChatSummaryService` (currently tied to UI)
3. System prompt / context injection mechanism

## Proposed Solutions

### Option 1: Create Agent Tool Registry (Future Work)
- **Pros:** Enables agent discovery and invocation
- **Cons:** Significant new feature
- **Effort:** Large (1-2 days)
- **Risk:** Low

```swift
public struct AgentTool {
    let name: String
    let description: String
    let execute: ([String: Any]) -> Signal<Any, Error>
}

public class AgentToolRegistry {
    static let shared = AgentToolRegistry()
    func register(_ tool: AgentTool) { ... }
    func listTools() -> [AgentTool] { ... }
}
```

### Option 2: Extract ChatSummaryService
- **Pros:** Decouples summary from UI
- **Cons:** Refactoring needed
- **Effort:** Medium (4-6 hours)
- **Risk:** Low

## Recommended Action

Track for future sprint. Current services establish good primitives - agent tooling can be added incrementally.

## Acceptance Criteria

- [ ] Services documented for agent consumption
- [ ] ChatSummaryService extracted (separate PR)
- [ ] Agent context provider implemented (separate PR)

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Agent-native reviewer assessed gaps |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
