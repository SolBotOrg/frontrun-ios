# Typography System

Complete font and text style documentation for Frontrun iOS (Telegram fork).

## Font Family

The app uses **SF Pro** (system font) by default. Users can toggle `useSystemFont` in settings.

```swift
// Font access via Display module
Font.regular(17.0)      // SF Pro Regular
Font.medium(17.0)       // SF Pro Medium
Font.semibold(17.0)     // SF Pro Semibold
Font.bold(17.0)         // SF Pro Bold
```

## Font Size Scale

The app defines a `PresentationFontSize` enum that controls dynamic text sizing:

| Size | Enum Case | Base Display Size |
|------|-----------|-------------------|
| Extra Small | `.extraSmall` | 14pt |
| Small | `.small` | 15pt |
| Medium | `.medium` | 16pt |
| **Regular (Default)** | `.regular` | **17pt** |
| Large | `.large` | 19pt |
| Extra Large | `.extraLarge` | 23pt |
| Extra Large X2 | `.extraLargeX2` | 26pt |

## Common Text Styles

### Primary Text (List Items, Titles)
```swift
Font.regular(presentationData.listsFontSize.baseDisplaySize)  // Default: 17pt
// Color: theme.list.itemPrimaryTextColor
```

### Secondary Text (Subtitles, Descriptions)
```swift
// Calculated as proportion of base size
Font.regular(floor(fontSize.baseDisplaySize * 13.0 / 17.0))  // Default: ~13pt
// Color: theme.list.itemSecondaryTextColor
```

### Chat Message Text
```swift
// In ChatPresentationData
let baseFontSize = fontSize.baseDisplaySize  // Default: 17pt
messageFont = Font.regular(baseFontSize)
messageBoldFont = Font.bold(baseFontSize)
messageBlockQuoteFont = Font.regular(baseFontSize - 1.0)
messageEmojiFont = Font.regular(53.0)  // Large emoji
```

### Navigation Title
```swift
Font.medium(17.0)  // SF Pro Medium 17pt
// Color: theme.rootController.navigationBar.primaryTextColor
```

### Navigation Button
```swift
Font.regular(17.0)  // SF Pro Regular 17pt
// Color: theme.rootController.navigationBar.buttonColor
```

### Tab Bar Label
```swift
Font.regular(10.0)  // Small label under icons
// Active: theme.rootController.tabBar.selectedTextColor
// Inactive: theme.rootController.tabBar.textColor
```

### Section Header
```swift
Font.regular(13.0)  // Uppercase section headers
// Color: theme.list.sectionHeaderTextColor (0x6d6d72)
```

### Badge Text
```swift
Font.bold(10.0)  // Scam/Fake badges, notification counts
// Color: theme.chatList.unreadBadgeActiveTextColor
```

---

## Figma Typography Specs

From Figma design system (File ID: `4IHvwZKJ8tWb8lkJMGUXjU`):

### Chat List Row
| Element | Font | Size | Weight | Tracking |
|---------|------|------|--------|----------|
| Contact name | SF Pro | 17px | Medium | -0.43px |
| Last message | SF Pro | 15px | Regular | -0.24px |
| Timestamp | SF Pro | 14px | Regular | -0.15px |

### Settings/List Items
| Element | Font | Size | Weight |
|---------|------|------|--------|
| Item title | SF Pro | 17px | Regular |
| Item value | SF Pro | 17px | Regular |
| Section header | SF Pro | 13px | Regular (Uppercase) |
| Footer text | SF Pro | 13px | Regular |

---

## Letter Spacing (Tracking)

iOS uses negative tracking for tighter text at larger sizes:

| Size | Tracking (approx) |
|------|-------------------|
| 10pt | 0px |
| 13pt | -0.08px |
| 14pt | -0.15px |
| 15pt | -0.24px |
| 17pt | -0.43px |

---

## Line Height

Standard line heights follow iOS conventions:
- **Body text**: ~1.2x font size
- **Titles**: ~1.1x font size
- **Captions**: ~1.3x font size

---

## Dynamic Type Support

Font sizes respect user's Dynamic Type setting via `PresentationFontSize`:

```swift
// Access current font size
let fontSize = presentationData.chatFontSize
let listsFontSize = presentationData.listsFontSize

// Get actual point size
let pointSize = fontSize.baseDisplaySize  // e.g., 17.0 for .regular

// Create font
let font = Font.regular(pointSize)
```

---

## Source Files

| Purpose | Path |
|---------|------|
| Font extensions | `submodules/Display/Source/Font.swift` |
| Font size enum | `submodules/TelegramUIPreferences/Sources/PresentationThemeSettings.swift` |
| baseDisplaySize | `submodules/TelegramPresentationData/Sources/ComponentsThemes.swift` |
| Chat fonts | `submodules/TelegramPresentationData/Sources/ChatPresentationData.swift` |
