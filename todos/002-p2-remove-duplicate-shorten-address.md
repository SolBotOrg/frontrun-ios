---
id: "002"
priority: P2
status: resolved
category: duplication
files:
  - Frontrun/FRSummaryUI/Sources/Components/SummarySheetScreenComponent.swift
  - Frontrun/FRSummaryUI/Sources/Views/TokenInfoActionSheet.swift
created: 2026-01-24
source: code-review
---

# Remove Duplicate shortenTokenAddress() Helper

## Problem

`shortenTokenAddress()` is defined in two files with identical implementation:
- `SummarySheetScreenComponent.swift` (used by TokenInfoActionSheet presentation)
- `TokenInfoActionSheet.swift` (used by token info display)

## Current Code (duplicated)

```swift
private func shortenTokenAddress(_ address: String) -> String {
    guard address.count > 12 else { return address }
    let prefix = address.prefix(6)
    let suffix = address.suffix(4)
    return "\(prefix)...\(suffix)"
}
```

## Action

1. Keep the function in `TokenInfoActionSheet.swift` (closer to its primary usage)
2. Remove from `SummarySheetScreenComponent.swift`
3. Make internal (not private) so SummarySheetScreenComponent can use it

Alternative: Move to FRModels as a String extension if needed elsewhere.

## Verification

```bash
# Check both files compile after change
bazel build //Frontrun/FRSummaryUI:FRSummaryUI -c dbg --ios_multi_cpus=sim_arm64
```
