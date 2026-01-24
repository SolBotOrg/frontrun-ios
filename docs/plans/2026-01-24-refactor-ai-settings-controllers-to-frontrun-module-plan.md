---
title: Refactor AI Settings Controllers to Frontrun Module
type: refactor
date: 2026-01-24
---

# Refactor AI Settings Controllers to Frontrun Module

## Overview

Move `FrontrunAISettingsController.swift` and `FrontrunAISummarySettingsController.swift` from `submodules/SettingsUI/Sources/` to a new `Frontrun/FRSettingsUI/` module to comply with the frontrun-eng principle: **"All code in `Frontrun/` - Never modify `submodules/`"**.

## Problem Statement

The AI settings controllers are currently located in `submodules/SettingsUI/Sources/`:
- `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift`
- `submodules/SettingsUI/Sources/FrontrunAISummarySettingsController.swift`

This violates the core frontrun-eng rule that all Frontrun code must live in `Frontrun/` to:
1. Isolate from Telegram upstream changes
2. Make merge conflict resolution easier
3. Keep clear separation between Frontrun features and Telegram base code

## Proposed Solution

Create a new `Frontrun/FRSettingsUI/` module containing the AI settings controllers, then update import statements and BUILD dependencies.

## Technical Approach

### Module Structure

```
Frontrun/FRSettingsUI/
├── BUILD
└── Sources/
    ├── FRAISettingsController.swift      # Renamed from FrontrunAISettingsController
    └── FRAISummarySettingsController.swift # Renamed from FrontrunAISummarySettingsController
```

### Implementation Phases

#### Phase 1: Create FRSettingsUI Module

**Task 1.1: Create directory structure**
```bash
mkdir -p Frontrun/FRSettingsUI/Sources
```

**Task 1.2: Create BUILD file**

Create `Frontrun/FRSettingsUI/BUILD`:

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRSettingsUI",
    module_name = "FRSettingsUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        # Frontrun modules
        "//Frontrun/FRServices:FRServices",

        # Signal kit
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",

        # Telegram context and core
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Postbox:Postbox",

        # Display
        "//submodules/Display:Display",

        # ItemList UI framework (for settings screens)
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",

        # Alert and prompt UI
        "//submodules/AlertUI:AlertUI",
        "//submodules/PromptUI:PromptUI",

        # Searchable selection (for model picker)
        "//submodules/SearchableSelectionScreen:SearchableSelectionScreen",
    ],
    visibility = ["//visibility:public"],
)
```

#### Phase 2: Move and Rename Controllers

**Task 2.1: Move FrontrunAISettingsController.swift**

Move `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift` to `Frontrun/FRSettingsUI/Sources/FRAISettingsController.swift`

Changes in the file:
- Keep all imports (they remain valid)
- Rename internal types to use `FR` prefix for consistency:
  - `AISettingsControllerArguments` → `FRAISettingsControllerArguments`
  - `AISettingsSection` → `FRAISettingsSection`
  - `AISettingsEntry` → `FRAISettingsEntry`
  - `AISettingsControllerState` → `FRAISettingsControllerState`
  - `aiSettingsControllerEntries` → `frAISettingsControllerEntries`
- Keep `aiSettingsController(context:)` public function name unchanged (to minimize callsite changes)

**Task 2.2: Move FrontrunAISummarySettingsController.swift**

Move `submodules/SettingsUI/Sources/FrontrunAISummarySettingsController.swift` to `Frontrun/FRSettingsUI/Sources/FRAISummarySettingsController.swift`

Changes in the file:
- Keep all imports
- Rename internal types:
  - `AISummarySettingsControllerArguments` → `FRAISummarySettingsControllerArguments`
  - `AISummarySettingsSection` → `FRAISummarySettingsSection`
  - `AISummarySettingsEntry` → `FRAISummarySettingsEntry`
  - `AISummarySettingsControllerState` → `FRAISummarySettingsControllerState`
  - `aiSummarySettingsControllerEntries` → `frAISummarySettingsControllerEntries`
- Keep `aiSummarySettingsController(context:)` public function name unchanged

#### Phase 3: Update Dependencies

**Task 3.1: Update TelegramUI/BUILD**

Add FRSettingsUI dependency:
```python
"//Frontrun/FRSettingsUI:FRSettingsUI",
```

**Task 3.2: Update FRSummaryUI/BUILD**

Replace SettingsUI dependency with FRSettingsUI:
```python
# Remove (if only used for settings controllers):
# "//submodules/SettingsUI:SettingsUI",
# Add:
"//Frontrun/FRSettingsUI:FRSettingsUI",
```

**Task 3.3: Update SettingsUI/BUILD**

Remove FRServices dependency since it's no longer needed:
```python
# Remove:
# "//Frontrun/FRServices:FRServices",
```

#### Phase 4: Update Import Statements

**Task 4.1: Update ChatControllerLoadDisplayNode.swift**

Change import from `SettingsUI` to `FRSettingsUI`:
```swift
// Remove (if only used for AI settings):
// import SettingsUI

// Add:
import FRSettingsUI
```

**Task 4.2: Update PeerInfoScreenSettingsActions.swift**

```swift
// Add:
import FRSettingsUI
```

**Task 4.3: Update SummarySheetScreenComponent.swift**

```swift
// Remove:
// import SettingsUI

// Add:
import FRSettingsUI
```

#### Phase 5: Update UPSTREAM_MODIFICATIONS.md

Add entry for the new module:
```markdown
### Frontrun/FRSettingsUI

**Purpose:** AI settings UI controllers (moved from SettingsUI)

**Created:** 2026-01-24

**Files:**
- `FRAISettingsController.swift` - Main AI settings screen
- `FRAISummarySettingsController.swift` - Summary-specific settings
```

Update TelegramUI/BUILD entry:
```markdown
**Changes:**
```python
# Add to deps section:
"//Frontrun/FRServices:FRServices",
"//Frontrun/FRModels:FRModels",
"//Frontrun/FRSummaryUI:FRSummaryUI",
"//Frontrun/FRSettingsUI:FRSettingsUI",  # NEW
```
```

#### Phase 6: Delete Original Files

**Task 6.1: Remove files from SettingsUI**

Delete:
- `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift`
- `submodules/SettingsUI/Sources/FrontrunAISummarySettingsController.swift`

## Acceptance Criteria

### Functional Requirements

- [x] New `Frontrun/FRSettingsUI/` module exists with BUILD file
- [x] Both settings controllers moved and renamed with `FR` prefix
- [x] All import statements updated in calling files
- [x] Original files deleted from `submodules/SettingsUI/Sources/`
- [x] FRServices dependency removed from SettingsUI BUILD

### Build Verification

- [x] `bazel build Telegram/Telegram -c dbg --ios_multi_cpus=sim_arm64` succeeds
- [ ] AI Settings accessible from Settings > AI Assistant (manual test required)
- [ ] Summary Settings accessible from Summary sheet > Settings gear (manual test required)
- [ ] All settings persist correctly (API key, model, message count, etc.) (manual test required)

### Quality Gates

- [x] No compiler warnings (`-warnings-as-errors` enforced)
- [x] No references to old file locations remain
- [x] UPSTREAM_MODIFICATIONS.md updated

## Files to Create

| File | Purpose |
|------|---------|
| `Frontrun/FRSettingsUI/BUILD` | Bazel build configuration |
| `Frontrun/FRSettingsUI/Sources/FRAISettingsController.swift` | Main AI settings |
| `Frontrun/FRSettingsUI/Sources/FRAISummarySettingsController.swift` | Summary settings |

## Files to Modify

| File | Change |
|------|--------|
| `submodules/TelegramUI/BUILD` | Add FRSettingsUI dep |
| `Frontrun/FRSummaryUI/BUILD` | Replace SettingsUI with FRSettingsUI dep |
| `submodules/SettingsUI/BUILD` | Remove FRServices dep |
| `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift` | Update import |
| `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift` | Add import |
| `Frontrun/FRSummaryUI/Sources/Components/SummarySheetScreenComponent.swift` | Update import |
| `docs/guidelines/UPSTREAM_MODIFICATIONS.md` | Document changes |

## Files to Delete

| File | Reason |
|------|--------|
| `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift` | Moved to Frontrun/ |
| `submodules/SettingsUI/Sources/FrontrunAISummarySettingsController.swift` | Moved to Frontrun/ |

## Risk Analysis

### Low Risk
- This is a straightforward move operation
- Public API (`aiSettingsController`, `aiSummarySettingsController`) remains unchanged
- No logic changes, only file location and naming

### Mitigation
- Keep public function names unchanged to minimize callsite changes
- Build verification at each phase
- Manual testing of settings flow after completion

## References

### Internal References
- Current AI Settings: `submodules/SettingsUI/Sources/FrontrunAISettingsController.swift`
- Current Summary Settings: `submodules/SettingsUI/Sources/FrontISummarySettingsController.swift`
- FRSummaryUI BUILD pattern: `Frontrun/FRSummaryUI/BUILD`
- Upstream modifications tracker: `docs/guidelines/UPSTREAM_MODIFICATIONS.md`

### Guidelines
- frontrun-eng skill: "All code in `Frontrun/` - Never modify `submodules/`"
- Module naming: `FR*` prefix for all Frontrun modules
