---
status: pending
priority: p2
issue_id: "002"
tags: [code-review, performance, memory, pr-15]
dependencies: []
---

# URLSession Memory Leak in AIService Streaming

## Problem Statement

Each streaming request in `AIService` creates a new `URLSession` that is never invalidated. The session retains a strong reference to its delegate until invalidated, causing memory accumulation.

## Findings

**File:** `Frontrun/FRServices/Sources/AIService.swift`
**Lines:** 293-301

```swift
private func performStreamingRequest(
    request: URLRequest,
    subscriber: Subscriber<AIStreamChunk, AIError>
) -> URLSessionDataTask {
    let delegate = StreamingDelegate(subscriber: subscriber, configuration: configuration)
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    let task = session.dataTask(with: request)
    task.resume()
    return task
    // Session is NEVER invalidated!
}
```

**Impact:**
- URLSession instances accumulate over time
- Each session holds strong reference to delegate
- Memory grows with each streaming request

## Proposed Solutions

### Option 1: Invalidate Session on Completion (Recommended)
- **Pros:** Simple fix, proper cleanup
- **Cons:** None
- **Effort:** Small (30 minutes)
- **Risk:** Very Low

```swift
// In StreamingDelegate:
weak var session: URLSession?

func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    // ... existing error handling ...

    // Clean up session
    session.finishTasksAndInvalidate()
    receivedData = Data()  // Also clear buffer
}
```

### Option 2: Reuse Single URLSession
- **Pros:** More efficient, fewer session objects
- **Cons:** Need to manage delegate per-request differently
- **Effort:** Medium (2 hours)
- **Risk:** Low

## Recommended Action

**Option 1** - Add `session.finishTasksAndInvalidate()` in the completion handler.

## Technical Details

**Affected files:**
- `Frontrun/FRServices/Sources/AIService.swift`

## Acceptance Criteria

- [ ] URLSession is invalidated after streaming completes
- [ ] No memory growth observed during repeated AI requests
- [ ] Streaming functionality works correctly

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-24 | Identified in PR #15 code review | Performance agent found memory leak |

## Resources

- PR: https://github.com/SolBotOrg/frontrun-ios/pull/15
- Apple URLSession invalidation: https://developer.apple.com/documentation/foundation/urlsession/1407428-finishtasksandinvalidate
