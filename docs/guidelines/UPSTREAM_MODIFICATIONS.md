# Upstream Modifications Tracker

> Track all modifications to Telegram upstream files to make merge conflict resolution easier.

## Overview

This file tracks every modification made to upstream Telegram files. When syncing with upstream, use this as a checklist to re-apply Frontrun changes.

---

## Modified Files

### submodules/TelegramUI/BUILD

**Purpose:** Add Frontrun module dependencies

**Location:** deps array (around line 450+)

**Changes:**
```python
# Add to deps section:
"//Frontrun/FRServices:FRServices",
"//Frontrun/FRModels:FRModels",
"//Frontrun/FRSummaryUI:FRSummaryUI",
"//Frontrun/FRSettingsUI:FRSettingsUI",
```

**Conflict Resolution:** Simply append to deps array. Order doesn't matter.

---

### submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift

**Purpose:** Import and use FRSummaryUI for AI chat summary feature

**Location:** Import section and summary button handler (around line 1568)

**Changes:**
```swift
// Add imports:
import FRSummaryUI
import FRSettingsUI

// In summary button handler, replace:
// let controller = ChatSummarySheetScreen(...)
// with:
let controller = FRSummarySheetScreen(context: strongSelf.context, peerId: peerId)
```

**Conflict Resolution:** Add imports, update class reference from `ChatSummarySheetScreen` to `FRSummarySheetScreen`.

---

### submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenSettingsActions.swift

**Purpose:** Import FRSettingsUI for AI settings controller

**Location:** Import section

**Changes:**
```swift
// Add import:
import FRSettingsUI
```

**Conflict Resolution:** Add import alongside existing SettingsUI import.

---

### submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/BUILD

**Purpose:** Add FRSettingsUI dependency for AI settings controller

**Location:** deps array

**Changes:**
```python
# Add to deps section:
"//Frontrun/FRSettingsUI:FRSettingsUI",
```

**Conflict Resolution:** Simply append to deps array. Order doesn't matter.

---

### submodules/TelegramUI/Sources/TelegramRootController.swift

**Purpose:** Inject Frontrun tabs into tab bar

**Location:** `addRootControllers(showCallsTab:)` method

**Changes:**
```swift
// After building controllers array, before setControllers():

#if FRONTRUN
import FRIntegration
self.addFrontrunTabs(to: &controllers)
#endif
```

**Conflict Resolution:** Find `setControllers` call, add hook before it.

---

### submodules/TelegramUI/Sources/Chat/ChatController.swift

**Purpose:** Token detection in chat messages

**Location:** Message display logic (around line 890+)

**Changes:**
```swift
// In message rendering:

#if FRONTRUN
import FRIntegration
self.handleFrontrunTokenDetection(message)
#endif
```

**Conflict Resolution:** Find message display code, add hook.

---

## Build Configuration

### Telegram/BUILD or .bazelrc

**Purpose:** Enable FRONTRUN compiler flag

**Changes:**
```python
# Add to swift_copts or defines:
"FRONTRUN=1"
```

---

## Sync Workflow

When merging upstream:

1. **Run merge:**
   ```bash
   git fetch upstream
   git merge upstream/master
   ```

2. **Check this file for each conflict:**
   - Is it a file we modified?
   - Re-apply our changes (documented above)

3. **Verify integration points:**
   ```bash
   grep -r "FRONTRUN" submodules/TelegramUI/Sources/
   ```

4. **Test build:**
   ```bash
   bazel build Telegram/Telegram --config=debug
   ```

5. **Update this file** if integration points changed.

---

## Change Log

| Date | File | Change | Reason |
|------|------|--------|--------|
| 2026-01-24 | TelegramUI/BUILD | Added FRServices + FRModels deps | Migrated from submodules to Frontrun/ |
| 2026-01-24 | TelegramUI/BUILD | Added FRSummaryUI dep | Migrated ChatSummarySheetScreen to FRSummaryUI |
| 2026-01-24 | ChatControllerLoadDisplayNode.swift | Import FRSummaryUI, use FRSummarySheetScreen | Migrated ChatSummarySheetScreen to FRSummaryUI |
| 2026-01-24 | SettingsUI/BUILD | Removed FRServices dep | Moved AI settings controllers to FRSettingsUI |
| 2026-01-24 | ChatListUI/BUILD | Added FRServices dep | Migrated from FrontrunAIModule |
| 2026-01-24 | TelegramUI/BUILD | Added FRSettingsUI dep | AI settings controllers moved to Frontrun/ |
| 2026-01-24 | ChatControllerLoadDisplayNode.swift | Added FRSettingsUI import | AI settings controllers moved to Frontrun/ |
| 2026-01-24 | PeerInfoScreenSettingsActions.swift | Added FRSettingsUI import | AI settings controllers moved to Frontrun/ |
| 2026-01-24 | PeerInfoScreen/BUILD | Added FRSettingsUI dep | AI settings controllers moved to Frontrun/ |
| 2026-01-24 | (planned) | TelegramRootController.swift | Tab injection |
| 2026-01-24 | (planned) | ChatController.swift | Token detection |

---

## Notes

- Keep modifications **minimal** - every change is a potential conflict
- Use **compiler flags** (`#if FRONTRUN`) to isolate our code
- Prefer **extensions** over direct modifications
- When upstream changes a file we modified, **check if our hook still makes sense**
