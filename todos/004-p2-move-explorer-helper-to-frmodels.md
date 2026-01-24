---
id: "004"
priority: P2
status: resolved
category: architecture
file: Frontrun/FRSummaryUI/Sources/Views/TokenInfoActionSheet.swift
created: 2026-01-24
source: code-review
---

# Move getExplorerName() to FRModels

## Problem

`getExplorerName()` helper function is defined in the UI layer but contains domain logic about blockchain explorers. This belongs in FRModels.

## Current Code

```swift
private func getExplorerName(for chain: String) -> String {
    switch chain.lowercased() {
    case "solana": return "Solscan"
    case "ethereum", "eth": return "Etherscan"
    case "base": return "BaseScan"
    case "bsc", "binance": return "BscScan"
    default: return "Explorer"
    }
}
```

## Action

1. Move to `Frontrun/FRModels/Sources/` as a public function or String extension
2. Update TokenInfoActionSheet to import from FRModels
3. Consider creating `FRChainInfo` struct with explorer URLs and names

## Verification

```bash
bazel build //Frontrun/FRModels:FRModels -c dbg --ios_multi_cpus=sim_arm64
bazel build //Frontrun/FRSummaryUI:FRSummaryUI -c dbg --ios_multi_cpus=sim_arm64
```
