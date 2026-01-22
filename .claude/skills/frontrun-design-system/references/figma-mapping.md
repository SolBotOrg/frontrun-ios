# Figma-to-Code Mapping

Reference for mapping Figma designs to Frontrun iOS code.

## Figma File Reference

- **File ID**: `4IHvwZKJ8tWb8lkJMGUXjU`
- **Name**: Telegram iOS UI Kit
- **Key Screens**: Chats, Settings, Contacts, Chat conversations

---

## Using Figma MCP

Fetch design specs using the Figma MCP server:

```
// Get screenshot of a Figma frame
mcp__plugin_figma_figma__get_screenshot

// Get design context (colors, typography, spacing)
mcp__plugin_figma_figma__get_design_context

// Get variable definitions (design tokens)
mcp__plugin_figma_figma__get_variable_defs

// Get metadata about the file
mcp__plugin_figma_figma__get_metadata
```

---

## Key Node IDs

| Screen | Node ID | Description |
|--------|---------|-------------|
| Chats | `5:89` | Chat list screen |
| Settings | `5:90` | Settings screen |
| Contacts | `5:91` | Contacts list |
| Chat | `5:92` | Chat conversation |

---

## Figma Component → Code Mapping

### Chat List Row

**Figma**: "Row" component (78px height)
**Code**: Custom node in `ChatListNode`

| Figma Element | Figma Spec | Code Property |
|---------------|------------|---------------|
| Container | Height: 78px | `itemHeight = 78` |
| Avatar | 62x62px, circular | `avatarSize = 62` |
| Name | SF Pro Medium 17px, -0.43 tracking | `Font.medium(17)` |
| Message | SF Pro Regular 15px | `Font.regular(15)` |
| Timestamp | SF Pro Regular 14px | `Font.regular(14)` |
| Left padding | 10px | `leftInset = 10` |
| Right padding | 16px | `rightInset = 16` |

### Settings Row

**Figma**: "Table Row" component (44px height)
**Code**: `ItemListDisclosureItem`, `ItemListSwitchItem`

| Figma Element | Figma Spec | Code Property |
|---------------|------------|---------------|
| Container | Height: 44px | Default item height |
| Icon | 29x29px | `icon: UIImage` |
| Title | SF Pro Regular 17px | `title: String` |
| Chevron | 7x12px, `#bab9be` | `disclosureArrowColor` |
| Horizontal padding | 16px | `insets.left/right` |

### Tab Bar

**Figma**: "Tab Bar" component
**Code**: `PresentationThemeRootTabBar`

| Figma Element | Figma Spec | Code Property |
|---------------|------------|---------------|
| Background | Blurred, `#f2f2f2` @ 90% | `backgroundColor` |
| Selected icon | `#0088ff` | `selectedIconColor` |
| Unselected icon | `#959595` | `iconColor` |
| Separator | `#b2b2b2` | `separatorColor` |
| Badge | `#ff3b30` | `badgeBackgroundColor` |

### Navigation Bar

**Figma**: "Toolbar" component
**Code**: `PresentationThemeRootNavigationBar`

| Figma Element | Figma Spec | Code Property |
|---------------|------------|---------------|
| Background | Blurred white | `blurredBackgroundColor` |
| Title | SF Pro Medium 17px, black | `primaryTextColor` |
| Button | SF Pro Regular 17px, accent | `buttonColor` |
| Separator | `#c8c7cc` | `separatorColor` |

---

## Color Token Mapping

| Figma Token | Hex | Theme Property |
|-------------|-----|----------------|
| Background/Primary | `#ffffff` | `list.plainBackgroundColor` |
| Background/Secondary | `#f2f2f7` | `list.blocksBackgroundColor` |
| Text/Primary | `#000000` | `list.itemPrimaryTextColor` |
| Text/Secondary | `#8e8e93` | `list.itemSecondaryTextColor` |
| Accent | `#0088ff` | `list.itemAccentColor` |
| Destructive | `#ff3b30` | `list.itemDestructiveColor` |
| Separator | `#c8c7cc` | `list.itemBlocksSeparatorColor` |

---

## Spacing System

| Figma Spacing | Value | Usage |
|---------------|-------|-------|
| XS | 4px | Icon-to-text gap |
| S | 8px | Related items |
| M | 10px | Standard padding |
| L | 16px | Section padding |
| XL | 35px | Section spacing |

---

## Extracting Specs from Figma

When implementing a new component:

1. **Get screenshot** to visualize the design:
   ```
   mcp__plugin_figma_figma__get_screenshot
   ```

2. **Get design context** for colors and typography:
   ```
   mcp__plugin_figma_figma__get_design_context
   ```

3. **Map to theme properties**:
   - Find corresponding `PresentationTheme` property
   - Use theme colors, never hardcode

4. **Match dimensions**:
   - Use Figma inspector for exact sizes
   - Apply to layout code

---

## Common Conversions

### Figma Tracking → iOS
Figma displays tracking in pixels. iOS uses `NSAttributedString` with `kern` attribute:

```swift
// Figma: -0.43px tracking at 17px font
let tracking = -0.43
let attributes: [NSAttributedString.Key: Any] = [
    .kern: tracking
]
```

### Figma Opacity → iOS Alpha
```swift
// Figma: 60% opacity
let alpha: CGFloat = 0.6
UIColor(rgb: 0x000000, alpha: alpha)
```

### Figma Drop Shadow → iOS
```swift
// Figma: X:0 Y:1 Blur:3 Color:#000000 @ 10%
layer.shadowColor = UIColor.black.cgColor
layer.shadowOffset = CGSize(width: 0, height: 1)
layer.shadowRadius = 1.5  // blur / 2
layer.shadowOpacity = 0.1
```

---

## Design Validation Checklist

When implementing from Figma:

- [ ] Colors match theme properties
- [ ] Typography uses correct Font calls
- [ ] Spacing matches Figma specs
- [ ] Corner radii are correct
- [ ] Shadows/effects are implemented
- [ ] Dark mode support works
- [ ] Dynamic type scales properly
