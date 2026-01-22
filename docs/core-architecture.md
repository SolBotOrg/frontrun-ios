# Core Architecture Guide

This document provides guidance for implementing new features in the Frontrun iOS app (Telegram fork) while maintaining consistency with the existing architecture and minimizing merge conflicts with upstream.

## Project Structure Overview

```
frontrun-ios/
├── Telegram/                    # Main app and extensions
│   ├── BUILD                    # Main Bazel build target
│   ├── Telegram-iOS/            # App entry points and resources
│   └── [Extensions]/            # NotificationService, Share, Widget, etc.
├── submodules/                  # 277 modular libraries (core codebase)
├── third-party/                 # External C/C++ libraries2
└── build-system/                # Bazel rules and build configuration
```

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `Telegram/` | App shell, entry points, extensions, resources |
| `submodules/` | Feature modules, UI components, core libraries |
| `third-party/` | External dependencies (codecs, crypto, etc.) |
| `docs/` | Architecture documentation (fork-specific) |

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Telegram/Telegram-iOS                     │
│              (App entry, resources, extensions)              │
├─────────────────────────────────────────────────────────────┤
│                        TelegramUI                            │
│           (Main UI aggregator - 600+ source files)           │
├─────────────────────────────────────────────────────────────┤
│    Feature Modules (ChatListUI, PeerInfoUI, TabBarUI...)    │
│              Each module = isolated feature                  │
├─────────────────────────────────────────────────────────────┤
│                      AccountContext                          │
│         (Dependency injection hub for all screens)           │
├─────────────────────────────────────────────────────────────┤
│              TelegramCore + Postbox + SwiftSignalKit         │
│           (Data layer, database, reactive patterns)          │
├─────────────────────────────────────────────────────────────┤
│         AsyncDisplayKit + Display (UI rendering layer)       │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure Pattern

Every feature module follows this structure:

```
submodules/FeatureUI/
├── BUILD                         # Bazel build file
├── Sources/
│   ├── FeatureController.swift   # Main controller (ViewController subclass)
│   ├── FeatureControllerNode.swift   # ASDisplayNode for layout
│   ├── FeatureItem.swift         # List item/cell definition
│   └── FeatureInteraction.swift  # User interaction callbacks
└── Resources/                    # Optional: images, assets
```

### Standard BUILD File

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FeatureUI",
    module_name = "FeatureUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramBaseController:TelegramBaseController",
        # Add minimal required dependencies
    ],
    visibility = ["//visibility:public"],
)
```

## Key Components

### AccountContext (Dependency Injection Hub)

All screens receive an `AccountContext` instance providing:
- `context.engine` - TelegramEngine for API calls
- `context.account` - Postbox database access
- `context.sharedContext` - App-wide shared services
- Factory methods for creating other controllers

```swift
public final class MyFeatureController: TelegramBaseController {
    private let context: AccountContext

    public init(context: AccountContext) {
        self.context = context
        super.init(context: context, ...)
    }
}
```

### SwiftSignalKit (Reactive Data Flow)

All data binding uses the Signal pattern:

```swift
// Subscribe to data changes
let disposable = dataSignal
    |> deliverOnMainQueue
    |> start(next: { [weak self] data in
        self?.updateUI(with: data)
    })

// Always clean up
deinit {
    self.disposable.dispose()
}
```

### AsyncDisplayKit (Async UI Rendering)

UI components use ASDisplayNode for 60fps performance:

```swift
public final class MyFeatureNode: ASDisplayNode {
    override func didLoad() {
        super.didLoad()
        // Setup after node loaded
    }

    override func layout() {
        super.layout()
        // Layout child nodes
    }
}
```

## Tab Bar Architecture

### Current Structure

```
TelegramRootController
    └── TabBarControllerImpl
        ├── ChatListController (Chats tab)
        ├── CallListController (Calls tab, optional)
        └── PeerInfoScreen (Settings tab)
```

### Adding a New Tab

1. **Create the module** in `submodules/YourTabUI/`
2. **Implement the controller** extending `TelegramBaseController`
3. **Set tab bar item properties**:

```swift
self.tabBarItem.title = "Wallet"
self.tabBarItem.image = UIImage(bundleImageName: "TabBar/Wallet")
self.tabBarItem.selectedImage = UIImage(bundleImageName: "TabBar/WalletFilled")
```

4. **Add to TelegramRootController** in `addRootControllers()`:

```swift
// In TelegramRootController.swift
let walletController = WalletController(context: self.context)
controllers.append(walletController)
```

## Best Practices for Fork Maintenance

### 1. Isolate Fork-Specific Code

**DO**: Create new modules in `submodules/` for fork features
```
submodules/FrontrunWalletUI/    # New fork-specific module
submodules/FrontrunAIChat/      # Another fork feature
```

**DON'T**: Heavily modify existing upstream modules

### 2. Minimal Upstream Modifications

When you must modify upstream files:
- Add code in clearly marked sections
- Use feature flags or conditionals
- Prefer extension points over inline changes

```swift
// MARK: - Frontrun Additions
#if FRONTRUN_WALLET_ENABLED
    controllers.append(walletController)
#endif
```

### 3. Module Dependency Strategy

**Tier 1 - Core utilities** (depend on these freely):
- SwiftSignalKit, AsyncDisplayKit, Display
- Postbox, TelegramCore, AccountContext

**Tier 2 - Feature modules** (be selective):
- ChatListUI, PeerInfoUI, TabBarUI
- Only depend on what you need

**Tier 3 - Your fork modules** (isolate):
- Keep fork modules self-contained
- Minimize dependencies on Tier 2 modules

### 4. Integration Points

**Recommended integration locations**:

| Feature Type | Integration Point |
|--------------|-------------------|
| New tab | `TelegramRootController.addRootControllers()` |
| Settings option | `PeerInfoScreen` data source |
| Chat action | `ChatControllerInteraction` callbacks |
| Deep link | `ResolvedUrl` enum in AccountContext |

### 5. File Organization

```
submodules/
├── [Upstream modules - minimize changes]
├── FrontrunCore/           # Shared fork utilities
├── FrontrunWalletUI/       # Wallet feature
├── FrontrunAIModule/       # AI features
└── FrontrunSettings/       # Fork-specific settings
```

## Example: Adding a Wallet Tab

### Step 1: Create Module

```
submodules/FrontrunWalletUI/
├── BUILD
└── Sources/
    ├── WalletController.swift
    ├── WalletControllerNode.swift
    └── WalletItem.swift
```

### Step 2: BUILD File

```python
swift_library(
    name = "FrontrunWalletUI",
    module_name = "FrontrunWalletUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/TelegramBaseController:TelegramBaseController",
        "//submodules/TabBarUI:TabBarUI",
    ],
    visibility = ["//visibility:public"],
)
```

### Step 3: Controller Implementation

```swift
import AccountContext
import Display
import TelegramBaseController

public final class WalletController: TelegramBaseController {
    private let context: AccountContext

    public init(context: AccountContext) {
        self.context = context
        super.init(context: context, navigationBarPresentationData: nil)

        self.tabBarItem.title = "Wallet"
        self.tabBarItem.image = UIImage(bundleImageName: "TabBar/Wallet")
    }

    override public func loadDisplayNode() {
        self.displayNode = WalletControllerNode(context: self.context)
    }
}
```

### Step 4: Add to Tab Bar

In `TelegramRootController.swift` (minimal change):

```swift
// Add import at top
import FrontrunWalletUI

// In addRootControllers(), add before settings:
let walletController = WalletController(context: self.context)
controllers.append(walletController)
```

### Step 5: Add to Telegram/BUILD

```python
deps = [
    "//submodules/FrontrunWalletUI:FrontrunWalletUI",
    # ... existing deps
]
```

## Merge Conflict Prevention

### Files to Avoid Modifying

| File | Risk Level | Alternative |
|------|------------|-------------|
| `Telegram/BUILD` | Medium | Add deps at end of list |
| `TelegramUI/Sources/*` | High | Create new modules instead |
| `AccountContext.swift` | High | Use extensions or new modules |
| `ChatListController.swift` | High | Create interaction hooks |

### Safe Modification Patterns

1. **Add, don't modify**: Append to arrays, add new cases to enums
2. **Use extensions**: Add functionality via Swift extensions in your modules
3. **Conditional compilation**: Use `#if FRONTRUN` flags for optional features
4. **New files over modified files**: Create new source files in existing modules when possible

### Rebasing Strategy

When rebasing on upstream:
1. Keep fork commits atomic and well-described
2. Resolve conflicts in favor of upstream, then re-apply fork changes
3. Maintain a list of intentionally modified upstream files
4. Consider cherry-picking specific upstream commits rather than rebasing everything

## Build Commands Reference

```bash
# Build for simulator
bazel build Telegram/Telegram \
    --features=swift.use_global_module_cache \
    --define=buildNumber=10000 \
    --define=telegramVersion=12.2.1 \
    -c dbg \
    --ios_multi_cpus=sim_arm64 \
    --//Telegram:disableProvisioningProfiles

# Install on simulator
unzip -o bazel-bin/Telegram/Telegram.ipa -d bazel-bin/Telegram/Telegram_extracted && \
xcrun simctl install booted bazel-bin/Telegram/Telegram_extracted/Payload/Telegram.app && \
xcrun simctl launch booted org.6638093a9a369d0c.Telegram
```

## Related Documentation

- `docs/chats-tab-architecture.md` - Detailed chat list implementation
- `docs/forked-repo-guide.md` - General fork maintenance guidance
- `CLAUDE.md` - Build commands and code style
