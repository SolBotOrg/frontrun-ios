# Component Patterns

UI component patterns and examples for Frontrun iOS (Telegram fork).

## Component Systems Overview

The codebase uses three UI systems:

| System | Module | Use For |
|--------|--------|---------|
| **ComponentFlow** | `submodules/ComponentFlow/` | Modern declarative UI |
| **AsyncDisplayKit** | `submodules/AsyncDisplayKit/` | Lists, performance-critical views |
| **Display** | `submodules/Display/` | Raw UIKit wrappers |

---

## Naming Conventions

```
{Feature}Controller      - View controllers (ItemListController, ChatController)
{Feature}Node           - ASDisplayNode subclasses (ChatListNode)
{Feature}Component      - ComponentFlow components (ButtonComponent)
ItemList{Type}Item      - List items (ItemListTextItem, ItemListSwitchItem)
```

---

## ItemList Components (Settings/Forms)

### ItemListSwitchItem
Toggle switch for boolean settings.

```swift
ItemListSwitchItem(
    presentationData: ItemListPresentationData(theme: presentationData.theme),
    icon: nil,                    // Optional left icon
    title: "Enable Feature",      // Main label
    text: nil,                    // Optional secondary text
    value: isEnabled,             // Current toggle state
    type: .regular,               // .regular or .icon
    enabled: true,                // Interactive state
    sectionId: self.section,      // Section grouping
    style: .blocks,               // .blocks or .plain
    updated: { value in
        // Handle toggle change
    }
)
```

### ItemListDisclosureItem
Navigation row with chevron.

```swift
ItemListDisclosureItem(
    presentationData: ItemListPresentationData(theme: presentationData.theme),
    icon: UIImage(bundleImageName: "Settings/Icon"),
    title: "Privacy Settings",
    label: "",                    // Right-side label
    sectionId: self.section,
    style: .blocks,
    action: {
        // Navigate to detail
    }
)
```

### ItemListTextItem
Footer/header text for sections.

```swift
ItemListTextItem(
    presentationData: ItemListPresentationData(theme: presentationData.theme),
    text: .markdown("This setting controls **important** features."),
    sectionId: self.section,
    style: .blocks,
    textAlignment: .natural,
    linkAction: { action in
        // Handle link taps
    }
)
```

### ItemListActionItem
Tappable action row.

```swift
ItemListActionItem(
    presentationData: ItemListPresentationData(theme: presentationData.theme),
    title: "Log Out",
    kind: .destructive,           // .generic, .destructive, .neutral
    alignment: .natural,
    sectionId: self.section,
    style: .blocks,
    action: {
        // Perform action
    }
)
```

---

## Chat List Row Dimensions

Standard chat list row layout:

```swift
// Dimensions
let rowHeight: CGFloat = 78
let avatarSize: CGFloat = 62
let leftPadding: CGFloat = 10
let rightPadding: CGFloat = 16
let avatarTextSpacing: CGFloat = 10
let titleDateSpacing: CGFloat = 4
let titleMessageSpacing: CGFloat = 2

// Layout structure
// |--10pt--|[Avatar 62x62]|--10pt--|[Title          Date]|--16pt--|
//                                   [Message preview     ]
```

---

## Settings Row Dimensions

Standard grouped table view row:

```swift
// Dimensions
let rowHeight: CGFloat = 44
let leftPadding: CGFloat = 16
let iconSize: CGFloat = 29
let iconPadding: CGFloat = 14
let accessoryPadding: CGFloat = 16

// With icon layout:
// |--16pt--|[Icon 29x29]|--14pt--|[Title]|--[Accessory]--|--16pt--|

// Without icon layout:
// |--16pt--|[Title]|--[Accessory]--|--16pt--|
```

---

## Navigation Bar

```swift
// Navigation bar colors from theme
let navBar = theme.rootController.navigationBar

navBar.primaryTextColor       // Title
navBar.buttonColor            // Buttons
navBar.blurredBackgroundColor // Background (with blur)
navBar.opaqueBackgroundColor  // Background (solid)
navBar.separatorColor         // Bottom line
```

---

## Tab Bar

```swift
// Tab bar configuration
let tabBar = theme.rootController.tabBar

tabBar.iconColor              // Inactive icon
tabBar.selectedIconColor      // Active icon
tabBar.textColor              // Inactive label
tabBar.selectedTextColor      // Active label
tabBar.backgroundColor        // Background
tabBar.separatorColor         // Top line
tabBar.badgeBackgroundColor   // Notification badge
```

---

## ComponentFlow Pattern

Modern declarative component:

```swift
final class MyComponent: Component {
    let text: String

    init(text: String) {
        self.text = text
    }

    static func ==(lhs: MyComponent, rhs: MyComponent) -> Bool {
        return lhs.text == rhs.text
    }

    final class View: UIView {
        private let textLabel = UILabel()

        func update(component: MyComponent, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            textLabel.text = component.text
            // Layout and return size
            return CGSize(width: availableSize.width, height: 44)
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}
```

---

## Button Styles

### Solid Button
```swift
// Primary action button
SolidRoundedButtonNode(
    title: "Continue",
    theme: SolidRoundedButtonTheme(
        backgroundColor: theme.list.itemCheckColors.fillColor,
        foregroundColor: theme.list.itemCheckColors.foregroundColor
    ),
    height: 50,
    cornerRadius: 10,
    gloss: false
)
```

### Glass Button
```swift
// Secondary button with glass effect
let glassButton = theme.rootController.navigationBar.glassBarButtonBackgroundColor
let glassForeground = theme.rootController.navigationBar.glassBarButtonForegroundColor
```

---

## Input Fields

```swift
// Text input field colors
let inputTheme = theme.list.itemInputField

inputTheme.backgroundColor    // 0xf2f2f7
inputTheme.strokeColor        // Border
inputTheme.placeholderColor   // Placeholder text
inputTheme.primaryColor       // Input text
inputTheme.controlColor       // Clear button, icons
```

---

## Source Files

| Component | Path |
|-----------|------|
| ItemListSwitchItem | `submodules/ItemListUI/Sources/Items/ItemListSwitchItem.swift` |
| ItemListDisclosureItem | `submodules/ItemListUI/Sources/Items/ItemListDisclosureItem.swift` |
| ItemListTextItem | `submodules/ItemListUI/Sources/Items/ItemListTextItem.swift` |
| ItemListActionItem | `submodules/ItemListUI/Sources/Items/ItemListActionItem.swift` |
| ComponentFlow base | `submodules/ComponentFlow/Source/Component.swift` |
| SolidRoundedButtonNode | `submodules/SolidRoundedButtonNode/` |
