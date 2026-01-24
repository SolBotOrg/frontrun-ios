---
title: Migrate FrontrunCryptoModule and FrontrunAIModule to Frontrun/ Directory
type: refactor
date: 2026-01-24
---

# Migrate FrontrunCryptoModule and FrontrunAIModule to Frontrun/ Directory

## Overview

Migrate existing Frontrun modules from `submodules/` to the proper `Frontrun/` directory structure following the frontrun-eng skill guidelines. This enforces isolation from Telegram upstream, uses `FR*` prefixes, and establishes the correct module dependency hierarchy.

## Problem Statement / Motivation

The current modules violate the frontrun-eng architecture principles:

1. **Wrong location**: `submodules/FrontrunCryptoModule/` and `submodules/FrontrunAIModule/` mix Frontrun code with Telegram submodules
2. **Naming inconsistency**: Module names don't follow `FR*` prefix convention
3. **Merge conflict risk**: Code in `submodules/` creates potential conflicts during upstream Telegram syncs
4. **Missing protocols**: Services lack protocol-first design (e.g., `DexScreenerService` has no protocol)
5. **Security concern**: `AIConfigurationStorage` stores API keys in `UserDefaults` instead of Keychain

## Proposed Solution

Migrate to the following structure following frontrun-eng guidelines:

```
Frontrun/
├── FRModels/
│   └── Sources/
│       └── DexTokenInfo.swift          # Data model (no deps)
├── FRNetworking/
│   └── Sources/
│       ├── DexScreenerClient.swift     # API client
│       └── AIAPIClient.swift           # AI API client
├── FRServices/
│   └── Sources/
│       ├── Protocols/
│       │   ├── DexScreenerServiceProtocol.swift
│       │   └── AIServiceProtocol.swift
│       ├── DexScreenerService.swift
│       ├── AIService.swift
│       └── AIConfiguration.swift
└── FRCore/
    └── Sources/
        └── AIConfigurationStorage.swift  # Secure storage
```

## Technical Considerations

### Architecture Impacts

- **TelegramUI**: Update BUILD to depend on `//Frontrun/FRServices:FRServices` instead of old modules
- **SettingsUI**: Update BUILD to depend on `//Frontrun/FRServices:FRServices`
- **Import statements**: All files importing `FrontrunAIModule` or `FrontrunCryptoModule` need import updates

### Module Separation

| Current | New Location | Rationale |
|---------|-------------|-----------|
| `DexTokenInfo` struct | `FRModels` | Pure data model, no dependencies |
| `DexScreenerService` | `FRServices` | Business logic with caching |
| `DexScreenerService.makeRequest()` | `FRNetworking` | HTTP client extraction |
| `AIConfiguration` | `FRServices` | Configuration model |
| `AIService` | `FRServices` | Business logic |
| `AIConfigurationStorage` | `FRCore` | Core infrastructure |

### Security Considerations

- `AIConfigurationStorage` currently uses `UserDefaults` for API keys
- Should migrate to Keychain for sensitive data (separate ticket)
- For this migration: maintain current behavior, add TODO comment

### Performance Implications

None expected - this is a structural reorganization without behavioral changes.

## Acceptance Criteria

### Functional Requirements

- [x] All code moved from `submodules/FrontrunCryptoModule/` to `Frontrun/`
- [x] All code moved from `submodules/FrontrunAIModule/` to `Frontrun/`
- [x] Module names use `FR*` prefix convention
- [x] Protocol defined for `DexScreenerService`
- [x] Protocol defined for `AIService`
- [x] BUILD files created with correct dependencies per frontrun-eng rules
- [x] TelegramUI BUILD updated to use new module paths
- [x] SettingsUI BUILD updated to use new module paths
- [x] All import statements updated in consuming files

### Non-Functional Requirements

- [x] Build succeeds: `bazel build Telegram/Telegram -c dbg --ios_multi_cpus=sim_arm64`
- [ ] No regressions in AI summary functionality (manual testing needed)
- [ ] No regressions in token info display (manual testing needed)

### Quality Gates

- [x] Old module directories deleted from `submodules/`
- [x] `docs/guidelines/UPSTREAM_MODIFICATIONS.md` updated
- [x] No direct TelegramUI imports in FRServices (only FRIntegration can do that)

## Success Metrics

- Zero merge conflicts in `submodules/` directory during upstream syncs
- Clear module boundaries following dependency rules
- Protocol-first service design enabling future testing

## Dependencies & Prerequisites

- No external dependencies
- Requires understanding of current usage in:
  - `submodules/TelegramUI/Sources/FrontrunChatSummarySheetScreen.swift`
  - `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift`
  - `submodules/SettingsUI/Sources/FrontrunAISummarySettingsController.swift`
  - `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift`

## Implementation Tasks

### Phase 1: Create New Module Structure

- [x] Create `Frontrun/FRModels/` with BUILD and `DexTokenInfo.swift`
- [ ] Create `Frontrun/FRNetworking/` with BUILD (deferred - not needed for MVP)
- [x] Create `Frontrun/FRServices/` with BUILD
- [x] Create protocol files in `FRServices/Sources/Protocols/`

### Phase 2: Migrate Code

- [x] Move `DexTokenInfo` to `FRModels`
- [x] Move `DexScreenerService` to `FRServices`, add protocol
- [x] Move `AIConfiguration`, `AIService` to `FRServices`, add protocols
- [x] Move `AIConfigurationStorage` to `FRServices` (kept in FRServices with FRCore TODO)

### Phase 3: Update Dependencies

- [x] Update `TelegramUI/BUILD` deps
- [x] Update `SettingsUI/BUILD` deps
- [x] Update `ChatListUI/BUILD` deps
- [x] Update import statements in all consuming Swift files

### Phase 4: Cleanup

- [x] Delete `submodules/FrontrunCryptoModule/`
- [x] Delete `submodules/FrontrunAIModule/`
- [x] Update `UPSTREAM_MODIFICATIONS.md`
- [x] Verify build and test manually

## Files to Create

### Frontrun/FRModels/BUILD

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRModels",
    module_name = "FRModels",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = ["//visibility:public"],
)
```

### Frontrun/FRServices/BUILD

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRServices",
    module_name = "FRServices",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//Frontrun/FRModels:FRModels",
    ],
    visibility = ["//visibility:public"],
)
```

### Frontrun/FRServices/Sources/Protocols/DexScreenerServiceProtocol.swift

```swift
import SwiftSignalKit
import FRModels

public protocol DexScreenerServiceProtocol {
    func fetchTokenInfo(address: String) -> Signal<DexTokenInfo?, NoError>
    func fetchMultipleTokenInfo(addresses: [String]) -> Signal<[String: DexTokenInfo], NoError>
    func clearCache()
}
```

### Frontrun/FRServices/Sources/Protocols/AIServiceProtocol.swift

```swift
import SwiftSignalKit

public protocol AIServiceProtocol {
    func sendMessage(messages: [AIMessage], stream: Bool) -> Signal<AIStreamChunk, AIError>
}
```

## Files to Modify

| File | Change |
|------|--------|
| `submodules/TelegramUI/BUILD` | Replace `//submodules/FrontrunAIModule` and `//submodules/FrontrunCryptoModule` with `//Frontrun/FRServices:FRServices` and `//Frontrun/FRModels:FRModels` |
| `submodules/SettingsUI/BUILD` | Replace `//submodules/FrontrunAIModule` with `//Frontrun/FRServices:FRServices` |
| `submodules/ChatListUI/BUILD` | Update if has Frontrun deps |
| `FrontrunChatSummarySheetScreen.swift` | Change `import FrontrunAIModule` to `import FRServices`, `import FrontrunCryptoModule` to `import FRModels` |
| `FrontrunAISettingsController.swift` | Change `import FrontrunAIModule` to `import FRServices` |
| `FrontrunAISummarySettingsController.swift` | Change imports |
| `ChatControllerLoadDisplayNode.swift` | Change imports if applicable |

## References & Research

### Internal References

- Architecture guide: `docs/guidelines/FRONTRUN_ARCHITECTURE.md`
- Module guide: `docs/guidelines/FRONTRUN_MODULE_GUIDE.md`
- Current crypto module: `submodules/FrontrunCryptoModule/Sources/DexScreenerService.swift`
- Current AI module: `submodules/FrontrunAIModule/Sources/`

### Frontrun-Eng Skill Rules

- All code in `Frontrun/` - Never modify `submodules/`
- Extension over modification
- `Signal<T, E>` for async - Not Combine, not async/await
- Protocol-first services - Define protocol before implementation

### Dependency Rules (from FRONTRUN_MODULE_GUIDE.md)

| Module Type | Can Import |
|-------------|------------|
| FRModels | SwiftSignalKit only |
| FRServices | FRModels, FRCore, FRNetworking, SwiftSignalKit |
| FRIntegration | All FR modules, TelegramUI |
