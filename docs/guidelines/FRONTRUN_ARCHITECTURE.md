# Frontrun Architecture Guide

> Reference documentation for building features on top of Telegram iOS with minimal merge conflicts.

## Core Principles

### 1. Isolation Over Integration

**Why:** Upstream Telegram updates frequently. Every line changed in Telegram code is a potential merge conflict.

**How:**
- All Frontrun code lives in `Frontrun/` directory (not `submodules/`)
- Use `FR*` prefix for all module names (consistent with Nicegram's `NG*`, Swiftgram's `SG*`)
- Files inside Frontrun directories don't need the prefix

**Example:**
```
✅ Frontrun/FRWallet/Sources/WalletService.swift
✅ Frontrun/FRTrading/Sources/QuickBuySheet.swift
❌ submodules/WalletService/  (mixes with Telegram modules)
❌ submodules/TelegramUI/Sources/FrontrunWallet.swift  (modifies upstream)
```

### 2. Extension Over Modification

**Why:** Swift extensions allow adding functionality without changing original files.

**How:**
- Extend Telegram classes in `Frontrun/FRIntegration/`
- Keep extensions focused and minimal
- Document which Telegram class is being extended

**Example:**
```swift
// File: Frontrun/FRIntegration/Sources/TelegramRootController+Frontrun.swift
extension TelegramRootController {
    func addFrontrunTabs(to controllers: inout [ViewController]) {
        // Add Alpha and Wallet tabs
    }
}
```

### 3. Single Integration Points

**Why:** Fewer touchpoints = fewer conflicts when syncing upstream.

**How:**
- Use compiler flags (`#if FRONTRUN`) for conditional compilation
- Create hook protocols that Telegram code can call into
- Limit modifications to 3-5 files maximum

**Files allowed to modify:**
| File | Change | Purpose |
|------|--------|---------|
| `TelegramUI/BUILD` | Add deps | Import Frontrun modules |
| `TelegramRootController.swift` | 3 lines | Tab injection hook |
| `ChatController.swift` | 3 lines | Token detection hook |

### 4. Protocol-Based Boundaries

**Why:** Protocols create clean interfaces between Frontrun and Telegram code, making testing and future changes easier.

**How:**
- Define protocols for all services in `FRServices/Protocols/`
- Inject dependencies through `FrontrunContext`
- Mock protocols for testing

**Example:**
```swift
public protocol WalletServiceProtocol {
    var hasWallet: Bool { get }
    func sign(transaction: Transaction) -> Signal<SignedTransaction, WalletError>
}

// Production
let service: WalletServiceProtocol = WalletService()

// Testing
let mockService: WalletServiceProtocol = MockWalletService()
```

### 5. Follow Existing Patterns

**Why:** Consistency with Telegram's patterns means less cognitive load and easier maintenance.

**Key patterns to match:**

| Pattern | Where Used | Our Usage |
|---------|-----------|-----------|
| `Signal<T, E>` | Everywhere | All async operations |
| `ValuePromise` | State management | UI state |
| `Disposable` | Subscriptions | All signal subscriptions |
| `ItemList` | Settings screens | Settings UI |
| `ASDisplayNode` | Complex UI | Performance-critical UI |
| `ViewController` | Navigation | All controllers |

---

## Module Organization

### Directory Structure

```
Frontrun/
├── FRCore/          # Dependency injection, feature flags, hooks
├── FRModels/        # Shared data models (Token, Wallet, etc.)
├── FRServices/      # Business logic (WalletService, TradingService)
├── FRNetworking/    # Network clients (RPC, DEX, price feeds)
├── FRAlphaUI/       # Alpha tab UI
├── FRWalletUI/      # Wallet tab UI
├── FRTradingUI/     # Trading UI (inline widget, quick buy)
├── FRCharts/        # Chart components
├── FRShared/        # Shared UI components
└── FRIntegration/   # Telegram integration layer (extensions)
```

### Dependency Rules

```
FRIntegration → FRAlphaUI, FRWalletUI, FRTradingUI
     ↓
FRAlphaUI, FRWalletUI, FRTradingUI → FRServices, FRShared
     ↓
FRServices → FRModels, FRNetworking, FRCore
     ↓
FRModels, FRNetworking → SwiftSignalKit (Telegram)
```

**Rules:**
1. UI modules never import other UI modules (use FRShared for shared components)
2. FRIntegration is the only module that imports TelegramUI
3. FRModels has no dependencies on other FR modules
4. All modules can depend on SwiftSignalKit

---

## Upstream Sync Workflow

### Weekly Sync Ritual

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Create sync branch
git checkout -b sync/upstream-$(date +%Y%m%d)

# 3. Merge upstream
git merge upstream/master

# 4. Resolve conflicts (should be minimal)
# Focus on: TelegramUI/BUILD, TelegramRootController.swift

# 5. Test thoroughly
bazel build Telegram/Telegram --config=debug

# 6. Create PR
git push origin sync/upstream-$(date +%Y%m%d)
gh pr create --repo SolBotOrg/frontrun-ios
```

### Conflict Resolution Priority

When conflicts occur:
1. **Keep upstream changes** for Telegram core functionality
2. **Re-apply Frontrun hooks** in the minimal locations
3. **Never fight upstream** - adapt our integration instead

### Tracking Upstream Changes

Keep a file tracking what we've modified:

```markdown
<!-- docs/UPSTREAM_MODIFICATIONS.md -->
# Upstream Modifications

## TelegramUI/BUILD
- Added FRIntegration dependency (line 450)

## TelegramRootController.swift
- Added `#if FRONTRUN` block in addRootControllers() (lines 234-238)

## ChatController.swift
- Added token detection hook call (lines 892-895)
```

---

## Feature Flags

All features should be toggleable:

```swift
// Frontrun/FRCore/Sources/FrontrunFeatures.swift

public enum FrontrunFeatures {
    @FeatureFlag("fr_trading_enabled", default: true)
    public static var tradingEnabled: Bool

    @FeatureFlag("fr_alpha_tab", default: true)
    public static var alphaTabEnabled: Bool

    @FeatureFlag("fr_wallet_tab", default: true)
    public static var walletTabEnabled: Bool

    @FeatureFlag("fr_inline_widgets", default: true)
    public static var inlineWidgetsEnabled: Bool
}
```

**Benefits:**
- Disable broken features without code changes
- A/B testing capability
- Gradual rollout
- Emergency kill switch

---

## BUILD File Template

```python
# File: Frontrun/FRExample/BUILD

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRExample",
    module_name = "FRExample",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//Frontrun/FRCore:FRCore",
        "//Frontrun/FRModels:FRModels",
    ],
    visibility = ["//visibility:public"],
)
```

---

## Next Steps

When implementing a new feature:

1. **Check this guide** - Does your approach follow the principles?
2. **Create module in Frontrun/** - Use `FR*` prefix
3. **Define protocols first** - In `FRServices/Protocols/`
4. **Follow Telegram patterns** - Signal-based, ItemList for settings
5. **Minimal integration** - Use extensions, not modifications
6. **Add feature flag** - Make it toggleable
7. **Update UPSTREAM_MODIFICATIONS.md** - Track what you touched
