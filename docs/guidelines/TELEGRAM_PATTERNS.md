# Telegram iOS Patterns Reference

> Quick reference for common patterns used in Telegram iOS codebase.

## Reactive Programming with SwiftSignalKit

### Signal Basics

Telegram uses `Signal<T, E>` for all async operations (not Combine or async/await).

```swift
import SwiftSignalKit

// Creating a signal
func fetchData() -> Signal<Data, FetchError> {
    return Signal { subscriber in
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                subscriber.putError(.network(error))
            } else if let data = data {
                subscriber.putNext(data)
                subscriber.putCompletion()
            }
        }
        task.resume()

        // Return disposable for cleanup
        return ActionDisposable {
            task.cancel()
        }
    }
}
```

### Signal Operators

```swift
// Transform values
signal |> map { value in transform(value) }

// Filter values
signal |> filter { value in condition(value) }

// Combine signals
combineLatest(signal1, signal2) |> map { a, b in (a, b) }

// Deliver on main queue (for UI updates)
signal |> deliverOnMainQueue

// Take first N values
signal |> take(1)

// Distinct values (requires Equatable)
signal |> distinctUntilChanged
```

### State Management with Promise/ValuePromise

```swift
// For complex state that may not be Equatable
private let statePromise = Promise<ControllerState>()
statePromise.set(.single(.loading))

// For Equatable state with deduplication
private let valuePromise = ValuePromise<Int>(ignoreRepeated: true)
valuePromise.set(42)  // Only emits if value changed

// Subscribe
disposable = statePromise.get()
    |> deliverOnMainQueue
    |> start(next: { state in
        self.updateUI(state)
    })
```

### Disposable Management

```swift
final class MyController: ViewController {
    // For multiple subscriptions
    private let disposeBag = DisposableSet()

    // For single replaceable subscription
    private var dataDisposable: Disposable?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add to bag (auto-disposed on deinit)
        disposeBag.add(
            someSignal.start(next: { [weak self] value in
                self?.handleValue(value)
            })
        )
    }

    func refresh() {
        // Replace existing subscription
        dataDisposable?.dispose()
        dataDisposable = fetchData().start(next: { [weak self] data in
            self?.update(data)
        })
    }

    deinit {
        disposeBag.dispose()
        dataDisposable?.dispose()
    }
}
```

---

## UI Patterns

### ViewController Structure

```swift
public final class MyController: ViewController {
    private let context: AccountContext

    // Access display node with type casting
    private var controllerNode: MyControllerNode {
        return self.displayNode as! MyControllerNode
    }

    public init(context: AccountContext) {
        self.context = context

        // nil for no navigation bar, or pass presentationData
        super.init(navigationBarPresentationData: nil)

        // Tab bar configuration
        self.tabBarItem.title = "My Tab"
        self.tabBarItem.image = UIImage(named: "TabIcon")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Create display node
    override public func loadDisplayNode() {
        self.displayNode = MyControllerNode()
        self.displayNodeDidLoad()
    }
}
```

### ASDisplayNode Structure

```swift
final class MyControllerNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let buttonNode: ASButtonNode

    override init() {
        self.titleNode = ASTextNode()
        self.buttonNode = ASButtonNode()

        super.init()

        // Enable touch handling
        self.automaticallyManagesSubnodes = false

        addSubnode(titleNode)
        addSubnode(buttonNode)

        setupNodes()
    }

    private func setupNodes() {
        titleNode.attributedText = NSAttributedString(
            string: "Title",
            attributes: [.font: UIFont.systemFont(ofSize: 17)]
        )

        buttonNode.addTarget(
            self,
            action: #selector(buttonTapped),
            forControlEvents: .touchUpInside
        )
    }

    @objc private func buttonTapped() {
        // Handle tap
    }

    // Layout
    override func layout() {
        super.layout()

        let bounds = self.bounds
        titleNode.frame = CGRect(x: 16, y: 16, width: bounds.width - 32, height: 24)
        buttonNode.frame = CGRect(x: 16, y: 56, width: bounds.width - 32, height: 44)
    }
}
```

### ItemList (Settings Screens)

```swift
// Entry types
private enum EntryId: Hashable {
    case header
    case toggle
    case action
}

private enum Entry: ItemListNodeEntry {
    case header(text: String)
    case toggle(id: EntryId, title: String, value: Bool)
    case action(id: EntryId, title: String)

    var stableId: EntryId {
        switch self {
        case .header: return .header
        case .toggle(let id, _, _): return id
        case .action(let id, _): return id
        }
    }

    static func <(lhs: Entry, rhs: Entry) -> Bool {
        // Define ordering
    }

    func item(presentationData: ItemListPresentationData, arguments: Arguments) -> ListViewItem {
        switch self {
        case .header(let text):
            return ItemListSectionHeaderItem(...)
        case .toggle(_, let title, let value):
            return ItemListSwitchItem(...)
        case .action(_, let title):
            return ItemListActionItem(...)
        }
    }
}

// Arguments for callbacks
private final class Arguments {
    let toggleChanged: (Bool) -> Void
    let actionTapped: () -> Void

    init(toggleChanged: @escaping (Bool) -> Void, actionTapped: @escaping () -> Void) {
        self.toggleChanged = toggleChanged
        self.actionTapped = actionTapped
    }
}
```

### Sheet Presentation (Component-Based)

```swift
public final class MySheet: ViewControllerComponentContainer {
    public init(context: AccountContext) {
        super.init(
            context: context,
            component: MySheetComponent(),
            navigationBarAppearance: .none,
            theme: .default
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Present as sheet
let sheet = MySheet(context: context)
controller.present(sheet, in: .window(.root))
```

---

## Theming

### Accessing Theme Colors

```swift
// In controller/node with presentationData
let backgroundColor = presentationData.theme.list.blocksBackgroundColor
let textColor = presentationData.theme.list.itemPrimaryTextColor
let accentColor = presentationData.theme.list.itemAccentColor

// Dark mode check
let isDark = presentationData.theme.overallDarkAppearance
```

### Common Theme Properties

```swift
// Backgrounds
presentationData.theme.list.blocksBackgroundColor
presentationData.theme.list.plainBackgroundColor
presentationData.theme.chatList.backgroundColor

// Text
presentationData.theme.list.itemPrimaryTextColor
presentationData.theme.list.itemSecondaryTextColor
presentationData.theme.list.itemAccentColor
presentationData.theme.list.itemDestructiveColor

// Elements
presentationData.theme.list.itemSeparatorColor
presentationData.theme.list.itemBlocksBackgroundColor
```

---

## Configuration Storage

### UserDefaults Pattern

```swift
public struct MyConfiguration: Equatable, Codable {
    public var enabled: Bool
    public var apiKey: String

    public init(enabled: Bool = false, apiKey: String = "") {
        self.enabled = enabled
        self.apiKey = apiKey
    }
}

public final class MyConfigurationStorage {
    private let userDefaultsKey = "frontrun.my.configuration"
    public static let shared = MyConfigurationStorage()

    public func getConfiguration() -> MyConfiguration {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(MyConfiguration.self, from: data) else {
            return MyConfiguration()
        }
        return config
    }

    public func saveConfiguration(_ config: MyConfiguration) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
```

---

## Common Imports

```swift
// Core
import Foundation
import UIKit

// Telegram Core
import SwiftSignalKit          // Reactive programming
import AccountContext          // Dependency injection
import TelegramPresentationData // Theming

// UI
import Display                  // Base UI utilities
import AsyncDisplayKit          // High-performance nodes
import TelegramUI              // Telegram UI components

// Frontrun
import FRCore
import FRModels
import FRServices
```

---

## Quick Reference

| Need | Pattern | Example |
|------|---------|---------|
| Async operation | `Signal<T, E>` | `fetchData() -> Signal<Data, Error>` |
| UI state | `ValuePromise<T>` | `ValuePromise<State>(ignoreRepeated: true)` |
| Subscription cleanup | `DisposableSet` | `disposeBag.add(signal.start(...))` |
| Settings screen | `ItemListController` | See ItemList pattern above |
| Tab controller | `ViewController` | Extend, set `tabBarItem` |
| Custom UI | `ASDisplayNode` | Subclass, override `layout()` |
| Theme colors | `presentationData.theme` | `theme.list.itemPrimaryTextColor` |
| Config storage | `Codable` + UserDefaults | See configuration pattern |
| Modal sheet | `ViewControllerComponentContainer` | See sheet pattern |
