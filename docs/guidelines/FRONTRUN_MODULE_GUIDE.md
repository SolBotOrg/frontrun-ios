# Frontrun Module Creation Guide

> Step-by-step guide for creating new feature modules.

## Creating a New Module

### 1. Create Directory Structure

```bash
mkdir -p Frontrun/FRNewFeature/Sources
```

### 2. Create BUILD File

```python
# File: Frontrun/FRNewFeature/BUILD

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRNewFeature",
    module_name = "FRNewFeature",
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

### 3. Add to TelegramUI/BUILD (if needed by main UI)

```python
# In submodules/TelegramUI/BUILD, add to deps:
"//Frontrun/FRNewFeature:FRNewFeature",
```

### 4. Create Source Files

Follow the patterns in [TELEGRAM_PATTERNS.md](./TELEGRAM_PATTERNS.md).

---

## Module Types

### Service Module (Business Logic)

```
FRNewService/
├── BUILD
└── Sources/
    ├── Protocols/
    │   └── NewServiceProtocol.swift
    ├── NewService.swift
    └── NewServiceError.swift
```

**Protocol first:**
```swift
// Sources/Protocols/NewServiceProtocol.swift
public protocol NewServiceProtocol {
    func doSomething() -> Signal<Result, NewServiceError>
}
```

**Implementation:**
```swift
// Sources/NewService.swift
public final class NewService: NewServiceProtocol {
    public func doSomething() -> Signal<Result, NewServiceError> {
        return Signal { subscriber in
            // Implementation
            return EmptyDisposable
        }
    }
}
```

### UI Module (Feature Tab/Screen)

```
FRNewUI/
├── BUILD
└── Sources/
    ├── NewTabController.swift
    ├── NewListNode.swift
    ├── NewItemNode.swift
    └── NewDetailController.swift
```

**Controller:**
```swift
public final class NewTabController: ViewController {
    private let context: FrontrunContext

    public init(context: FrontrunContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)

        self.tabBarItem.title = "New"
        self.tabBarItem.image = UIImage(named: "TabNew")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = NewListNode(context: context)
        self.displayNodeDidLoad()
    }
}
```

### Networking Module

```
FRNewNetworking/
├── BUILD
└── Sources/
    ├── NewAPIClient.swift
    ├── NewAPIEndpoints.swift
    └── NewAPIModels.swift
```

**Client:**
```swift
public final class NewAPIClient {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func fetchItems() -> Signal<[Item], APIError> {
        return Signal { subscriber in
            var request = URLRequest(url: self.baseURL.appendingPathComponent("/items"))
            request.httpMethod = "GET"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    subscriber.putError(.network(error))
                    return
                }

                guard let data = data else {
                    subscriber.putError(.noData)
                    return
                }

                do {
                    let items = try JSONDecoder().decode([Item].self, from: data)
                    subscriber.putNext(items)
                    subscriber.putCompletion()
                } catch {
                    subscriber.putError(.parsing(error))
                }
            }
            task.resume()

            return ActionDisposable { task.cancel() }
        }
    }
}
```

---

## Dependency Rules

### What Each Module Type Can Import

| Module Type | Can Import |
|-------------|------------|
| FRModels | SwiftSignalKit only |
| FRCore | FRModels, AccountContext, SwiftSignalKit |
| FRNetworking | FRModels, SwiftSignalKit |
| FRServices | FRModels, FRCore, FRNetworking, SwiftSignalKit |
| FR*UI | FRCore, FRServices, FRShared, Display, AsyncDisplayKit |
| FRShared | FRModels, Display, AsyncDisplayKit |
| FRIntegration | All FR modules, TelegramUI |

### Forbidden Dependencies

- **UI → UI**: Use FRShared for shared components
- **Services → UI**: Business logic must not depend on UI
- **Models → anything FR**: Models are foundational
- **Non-Integration → TelegramUI**: Only FRIntegration imports TelegramUI

---

## Adding a Feature Flag

```swift
// In FRCore/Sources/FrontrunFeatures.swift

public enum FrontrunFeatures {
    // Add new flag
    @FeatureFlag("fr_new_feature", default: false)
    public static var newFeatureEnabled: Bool
}
```

**Usage:**
```swift
if FrontrunFeatures.newFeatureEnabled {
    // Show new feature
}
```

---

## Registering in FrontrunContext

If your service needs to be accessible app-wide:

```swift
// In FRCore/Sources/FrontrunContext.swift

public final class FrontrunContext {
    // Add lazy property
    public lazy var newService: NewServiceProtocol = {
        NewService()
    }()
}
```

---

## Integration Checklist

When adding a new module:

- [ ] Created `Frontrun/FRNewModule/` directory
- [ ] Created BUILD file with proper dependencies
- [ ] Added to `TelegramUI/BUILD` deps (if needed)
- [ ] Defined protocol first (if service module)
- [ ] Added feature flag (if user-facing)
- [ ] Registered in FrontrunContext (if needed globally)
- [ ] Updated `docs/UPSTREAM_MODIFICATIONS.md` (if touched Telegram files)
- [ ] Tested build: `bazel build Telegram/Telegram --config=debug`

---

## Module Naming Conventions

| Type | Prefix | Example |
|------|--------|---------|
| Core/Infrastructure | `FRCore` | `FRCore` |
| Data Models | `FRModels` | `FRModels` |
| Services | `FR*` | `FRWallet`, `FRTrading`, `FRAlpha` |
| Networking | `FR*Networking` or `FR*Client` | `FRNetworking`, `FRJupiterClient` |
| UI Modules | `FR*UI` | `FRWalletUI`, `FRAlphaUI` |
| Shared Components | `FRShared` | `FRShared` |
| Integration | `FRIntegration` | `FRIntegration` |

---

## Common BUILD Dependencies

```python
# Core Telegram dependencies
"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
"//submodules/AccountContext:AccountContext",
"//submodules/TelegramPresentationData:TelegramPresentationData",
"//submodules/Display:Display",
"//submodules/AsyncDisplayKit:AsyncDisplayKit",

# Frontrun dependencies
"//Frontrun/FRCore:FRCore",
"//Frontrun/FRModels:FRModels",
"//Frontrun/FRServices:FRServices",
"//Frontrun/FRShared:FRShared",
```
