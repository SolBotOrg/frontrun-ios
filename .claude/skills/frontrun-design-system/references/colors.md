# Color System

Complete color token documentation for Frontrun iOS (Telegram fork).

## Color Format

Colors are defined using `UIColor(rgb:)` or `UIColor(rgb:alpha:)`:

```swift
UIColor(rgb: 0x0088ff)              // RGB hex
UIColor(rgb: 0x000000, alpha: 0.6)  // RGB hex with alpha
```

## Theme Access Pattern

Never hardcode colors. Always access through `PresentationTheme`:

```swift
// Get theme from presentationData
let theme = self.presentationData.theme

// Access specific color categories
theme.list.itemPrimaryTextColor
theme.chatList.titleColor
theme.rootController.navigationBar.buttonColor
```

---

## Day Theme Colors

### Accent Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `defaultDayAccentColor` | `0x0088ff` | Primary accent, links, buttons |

### Text Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Primary text | `0x000000` | Main text, titles |
| Secondary text | `0x8e8e93` | Subtitles, descriptions, timestamps |
| Disabled text | `0xd0d0d0` | Disabled states |
| Placeholder | `0xc8c8ce` | Input placeholders |
| Section header | `0x6d6d72` | List section headers |
| Link text | `0x004bad` | Inline links in messages |

### Background Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Plain background | `0xffffff` | Chat list, plain tables |
| Grouped background | `0xefeff4` | Settings, grouped tables |
| Item background | `0xffffff` | List item backgrounds |
| Pinned item | `0xf7f7f7` | Pinned chat background |
| Highlighted | `0xe5e5ea` | Selection highlight |
| Selected | `0xe9f0fa` | Selection state |
| Input fill | `0xf2f2f7` | Input field backgrounds |
| Blurred nav | `0xf2f2f2` @ 90% | Navigation bar blur |

### Semantic Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Destructive | `0xff3b30` | Delete, errors, scam |
| Success | `0x00b12c` | Secret chats, success states |
| Warning | `0xff9500` | Warnings |
| Badge red | `0xff3b30` | Notification badges |

### Separator Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Separator | `0xc8c7cc` | List separators, borders |
| Tab bar separator | `0xb2b2b2` | Tab bar top line |

### Icon Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Tab icon inactive | `0x959595` | Unselected tab icons |
| Tab icon active | `0x0088ff` | Selected tab icons |
| Disclosure arrow | `0xbab9be` | List disclosure arrows |
| Mute icon | `0xa7a7ad` | Muted chat indicator |
| Control color | `0x7e8791` | Navigation controls |

### Chat Bubble Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Incoming fill | `0xffffff` | Incoming message bubble |
| Incoming highlight | `0xd9f4ff` | Incoming bubble pressed |
| Outgoing fill | `0xe1ffc7` | Outgoing message bubble |
| Outgoing highlight | `0xbaff93` | Outgoing bubble pressed |
| Check color | `0x19c700` | Message sent checkmarks |

### Input Panel
| Token | Hex | Usage |
|-------|-----|-------|
| Panel background | Blurred | Input area background |
| Input field fill | `0xe9e9e9` | Text input background |
| Input placeholder | `0x8e8d92` | Input placeholder text |

---

## Dark Theme Colors

### Accent Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Default accent | `0x007aff` | Primary accent in dark mode |

### Text Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Primary text | `0xffffff` | Main text |
| Secondary text | `0x98989e` | Subtitles, descriptions |

### Background Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Plain background | `0x000000` | Main backgrounds |
| Grouped background | `0x1c1c1e` | Grouped table backgrounds |
| Item background | `0x1c1c1e` | List item backgrounds |

---

## Switch & Control Colors

```swift
PresentationThemeSwitch(
    frameColor: UIColor(rgb: 0xe9e9ea),      // Switch track border
    handleColor: UIColor(rgb: 0xffffff),     // Switch handle
    contentColor: UIColor(rgb: 0x35c759),    // Switch on state
    positiveColor: UIColor(rgb: 0x00c900),   // Positive action
    negativeColor: UIColor(rgb: 0xff3b30)    // Negative action
)
```

---

## Badge Colors

```swift
// Unread badge (active)
unreadBadgeActiveBackgroundColor: defaultDayAccentColor  // 0x0088ff
unreadBadgeActiveTextColor: UIColor(rgb: 0xffffff)

// Unread badge (inactive/muted)
unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xb6b6bb)
unreadBadgeInactiveTextColor: UIColor(rgb: 0xffffff)

// Reaction badge
reactionBadgeActiveBackgroundColor: UIColor(rgb: 0xFF2D55)

// Pinned badge
pinnedBadgeColor: UIColor(rgb: 0xb6b6bb)
```

---

## Story Ring Colors

```swift
// Unseen story
storyUnseenColors: PresentationThemeGradientColors(
    topColor: UIColor(rgb: 0x34C76F),
    bottomColor: UIColor(rgb: 0x3DA1FD)
)

// Unseen private story
storyUnseenPrivateColors: PresentationThemeGradientColors(
    topColor: UIColor(rgb: 0x7CD636),
    bottomColor: UIColor(rgb: 0x26B470)
)

// Seen story
storySeenColors: PresentationThemeGradientColors(
    topColor: UIColor(rgb: 0xD8D8E1),
    bottomColor: UIColor(rgb: 0xD8D8E1)
)
```

---

## Archive Avatar Colors

```swift
// Pinned archive
pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(
    backgroundColors: PresentationThemeGradientColors(
        topColor: UIColor(rgb: 0x72d5fd),
        bottomColor: UIColor(rgb: 0x2a9ef1)
    ),
    foregroundColor: UIColor(rgb: 0xffffff)
)

// Unpinned archive
unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(
    backgroundColors: PresentationThemeGradientColors(
        topColor: UIColor(rgb: 0xdedee5),
        bottomColor: UIColor(rgb: 0xc5c6cc)
    ),
    foregroundColor: UIColor(rgb: 0xffffff)
)
```

---

## Disclosure Action Colors

```swift
PresentationThemeItemDisclosureActions(
    neutral1: (fill: 0x4892f2, foreground: 0xffffff),  // Blue action
    neutral2: (fill: 0xf09a37, foreground: 0xffffff),  // Orange action
    destructive: (fill: 0xff3824, foreground: 0xffffff),  // Red delete
    constructive: (fill: 0x00c900, foreground: 0xffffff),  // Green action
    accent: (fill: accent, foreground: 0xffffff),  // Accent action
    warning: (fill: 0xff9500, foreground: 0xffffff),  // Warning
    inactive: (fill: 0xbcbcc3, foreground: 0xffffff)   // Inactive/archive
)
```

---

## Source Files

- `submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift`
- `submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift`
- `submodules/TelegramPresentationData/Sources/PresentationTheme.swift`
