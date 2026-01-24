# Frontrun iOS Documentation

> Engineering documentation for the Frontrun iOS app (Telegram fork with crypto trading features).

## Quick Links

| Document | Purpose |
|----------|---------|
| [FRONTRUN_ARCHITECTURE.md](./FRONTRUN_ARCHITECTURE.md) | Core principles for building on Telegram |
| [TELEGRAM_PATTERNS.md](./TELEGRAM_PATTERNS.md) | SwiftSignalKit, UI patterns, theming reference |
| [FRONTRUN_MODULE_GUIDE.md](./FRONTRUN_MODULE_GUIDE.md) | Step-by-step guide for creating modules |
| [SECURITY_GUIDELINES.md](./SECURITY_GUIDELINES.md) | Security requirements for wallet features |
| [UPSTREAM_MODIFICATIONS.md](./UPSTREAM_MODIFICATIONS.md) | Tracking changes to Telegram code |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontrun iOS                           │
├─────────────────────────────────────────────────────────────┤
│  FRIntegration    │ Bridge layer to Telegram               │
├───────────────────┼─────────────────────────────────────────┤
│  FRAlphaUI        │ Alpha feed tab                         │
│  FRWalletUI       │ Wallet/portfolio tab                   │
│  FRTradingUI      │ Inline trading widgets                 │
│  FRCharts         │ Price charts                           │
│  FRShared         │ Shared UI components                   │
├───────────────────┼─────────────────────────────────────────┤
│  FRServices       │ Business logic (wallet, trading, etc.) │
│  FRNetworking     │ RPC, DEX, price APIs                   │
├───────────────────┼─────────────────────────────────────────┤
│  FRCore           │ DI container, feature flags, hooks     │
│  FRModels         │ Token, Wallet, Transaction models      │
├─────────────────────────────────────────────────────────────┤
│                   Telegram iOS (upstream)                   │
│  TelegramUI │ TelegramCore │ SwiftSignalKit │ Display      │
└─────────────────────────────────────────────────────────────┘
```

## Key Principles

### 1. Minimize Merge Conflicts

All Frontrun code lives in `Frontrun/` directory. We touch only 3 Telegram files:
- `TelegramUI/BUILD` (add deps)
- `TelegramRootController.swift` (tab hook)
- `ChatController.swift` (token detection hook)

### 2. Follow Telegram Patterns

Use `Signal<T, E>` for async, `ASDisplayNode` for UI, `ItemList` for settings. See [TELEGRAM_PATTERNS.md](./TELEGRAM_PATTERNS.md).

### 3. Security First

Keys in Keychain only. Biometric for signing. Validate all external data. See [SECURITY_GUIDELINES.md](./SECURITY_GUIDELINES.md).

### 4. Feature Flags

Every feature should be toggleable via `FrontrunFeatures`.

## Getting Started

### Building

```bash
# Simulator build
bazel build Telegram/Telegram \
  --features=swift.use_global_module_cache \
  --verbose_failures \
  --jobs=16 \
  --define=buildNumber=10000 \
  --define=telegramVersion=12.2.1 \
  -c dbg \
  --ios_multi_cpus=sim_arm64 \
  --features=swift.enable_batch_mode \
  --//Telegram:disableProvisioningProfiles

# Install on simulator
unzip -o bazel-bin/Telegram/Telegram.ipa -d bazel-bin/Telegram/Telegram_extracted && \
xcrun simctl install booted bazel-bin/Telegram/Telegram_extracted/Payload/Telegram.app && \
xcrun simctl launch booted org.6638093a9a369d0c.Telegram
```

### Creating a New Module

See [FRONTRUN_MODULE_GUIDE.md](./FRONTRUN_MODULE_GUIDE.md) for the full guide.

Quick version:
1. Create `Frontrun/FRNewModule/` with BUILD file
2. Add to `TelegramUI/BUILD` deps
3. Follow patterns from existing modules

### Syncing with Upstream

```bash
git fetch upstream
git checkout -b sync/upstream-$(date +%Y%m%d)
git merge upstream/master
# Resolve conflicts using UPSTREAM_MODIFICATIONS.md
git push origin sync/upstream-$(date +%Y%m%d)
```

## Module Naming

| Prefix | Usage |
|--------|-------|
| `FR*` | All Frontrun modules |
| `FRCore` | Dependency injection, flags |
| `FRModels` | Data models |
| `FR*UI` | UI modules |
| `FRServices` | Business logic |
| `FRIntegration` | Telegram bridge |

## Git Workflow

- Always push to `SolBotOrg/frontrun-ios`, never upstream
- PRs: `gh pr create --repo SolBotOrg/frontrun-ios`
- Sync upstream weekly
