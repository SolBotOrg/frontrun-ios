---
id: "003"
priority: P2
status: resolved
category: naming
files:
  - Frontrun/FRSummaryUI/Sources/Components/SummarySheetScreenComponent.swift
  - Frontrun/FRSummaryUI/Sources/Components/SummaryContentComponent.swift
  - Frontrun/FRSummaryUI/Sources/Views/TokenInfoActionSheet.swift
created: 2026-01-24
source: code-review
---

# Add FR* Prefix to Internal Classes

## Problem

Per frontrun-eng conventions, all classes should use `FR*` prefix. The following internal classes lack this prefix:

| Current Name | Should Be |
|--------------|-----------|
| `SummarySheetScreenComponent` | `FRSummarySheetScreenComponent` |
| `SummaryContentComponent` | `FRSummaryContentComponent` |
| `TokenInfoActionSheetItem` | `FRTokenInfoActionSheetItem` |
| `TokenInfoActionSheetItemNode` | `FRTokenInfoActionSheetItemNode` |

## Action

Rename classes to use FR* prefix. These are internal to the module so no external references need updating.

## Files to Modify

1. `SummarySheetScreenComponent.swift` - rename class
2. `SummaryContentComponent.swift` - rename class
3. `TokenInfoActionSheet.swift` - rename both classes
4. `FRSummarySheetScreen.swift` - update reference to component

## Verification

```bash
bazel build //Frontrun/FRSummaryUI:FRSummaryUI -c dbg --ios_multi_cpus=sim_arm64
```
