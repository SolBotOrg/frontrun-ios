---
name: frontrun-design-system
description: Design system for Frontrun iOS (Telegram fork). Use when creating UI components, implementing new screens, styling views, or ensuring visual consistency. Provides color tokens, typography specs, spacing values, and component patterns that match the Telegram iOS design language.
---

# Frontrun iOS Design System

This skill provides design tokens, component patterns, and Figma-to-code mapping for building consistent UI in the Frontrun iOS app.

## Quick Reference

### Primary Colors
```swift
// Accent (links, buttons, selections)
let accent = UIColor(rgb: 0x0088ff)

// Text
let primaryText = UIColor(rgb: 0x000000)
let secondaryText = UIColor(rgb: 0x8e8e93)

// Backgrounds
let plainBackground = UIColor(rgb: 0xffffff)
let groupedBackground = UIColor(rgb: 0xefeff4)
let inputBackground = UIColor(rgb: 0xf2f2f7)

// Semantic
let destructive = UIColor(rgb: 0xff3b30)
let success = UIColor(rgb: 0x00b12c)
let warning = UIColor(rgb: 0xff9500)
```

### Standard Dimensions
```swift
// Row heights
let standardRowHeight: CGFloat = 78  // Chat list row
let settingsRowHeight: CGFloat = 44  // Settings/list items

// Avatars
let chatListAvatarSize: CGFloat = 62
let profileAvatarSize: CGFloat = 100

// Spacing
let horizontalPadding: CGFloat = 16
let listItemLeftPadding: CGFloat = 10
let sectionSpacing: CGFloat = 35
```

### Accessing Theme Colors

Always use `PresentationTheme` for colors - never hardcode:

```swift
// In a controller or node
let theme = self.presentationData.theme

// List colors
theme.list.itemPrimaryTextColor
theme.list.itemSecondaryTextColor
theme.list.itemAccentColor
theme.list.blocksBackgroundColor

// Chat list colors
theme.chatList.titleColor
theme.chatList.messageTextColor
theme.chatList.dateTextColor

// Navigation
theme.rootController.navigationBar.primaryTextColor
theme.rootController.tabBar.selectedIconColor
```

## Component Systems

The codebase uses three UI systems:

| System | Use For | Key Types |
|--------|---------|-----------|
| **ComponentFlow** | Modern declarative UI | `Component`, `CombinedComponent` |
| **AsyncDisplayKit** | Lists, performance-critical | `ASDisplayNode`, `ItemListController` |
| **Display** | Raw UIKit wrappers | `ViewController`, `NavigationBar` |

## Naming Conventions

```
{Feature}Controller      - View controllers
{Feature}Node           - ASDisplayNode subclasses
{Feature}Component      - ComponentFlow components
ItemList{Type}Item      - List items (ItemListTextItem, ItemListSwitchItem)
```

## Creating New Components

### Chat List Row Pattern
```swift
// Standard chat row dimensions
let rowHeight: CGFloat = 78
let avatarSize: CGFloat = 62
let leftPadding: CGFloat = 10
let rightPadding: CGFloat = 16
let avatarTextSpacing: CGFloat = 10
```

### Settings Row Pattern
```swift
// Standard settings item
let rowHeight: CGFloat = 44
let leftPadding: CGFloat = 16
let accessoryRightPadding: CGFloat = 16
```

## Reference Files

- `references/colors.md` - Complete color token documentation
- `references/typography.md` - Font system and text styles
- `references/components.md` - Component patterns and examples
- `references/figma-mapping.md` - Figma node to code mapping

## Key Source Files

| Purpose | Path |
|---------|------|
| Theme structure | `submodules/TelegramPresentationData/Sources/PresentationTheme.swift` |
| Day theme | `submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift` |
| Dark theme | `submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift` |
| ComponentFlow | `submodules/ComponentFlow/Source/` |
| List items | `submodules/ItemListUI/` |

## Figma Reference

- **File ID**: `4IHvwZKJ8tWb8lkJMGUXjU`
- **Key Screens**: Chats, Settings, Contacts, Chat conversations
- Use Figma MCP (`mcp__plugin_figma_figma__get_design_context`) to fetch current design specs
