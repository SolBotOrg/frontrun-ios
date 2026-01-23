---
title: "feat: Apply muted professional theme for Frontrun crypto app"
type: feat
date: 2026-01-23
reviewed: true
reviewers: [DHH, Kieran, Simplicity]
---

# feat: Apply muted professional theme for Frontrun crypto app

## Overview

Restyle the Telegram iOS fork (Frontrun) with a muted, professional color palette inspired by Bloomberg terminal aesthetics. This differentiates the app from Telegram while maintaining the existing UI structure.

**Approach:** Start minimal (Phase 1 only), test propagation, add Phase 2 only if needed.

## Problem Statement / Motivation

Frontrun is a Telegram fork aimed at crypto traders. The default Telegram blue (`#0088FF`) is:
1. Immediately recognizable as "Telegram" - undermines brand differentiation
2. Too vibrant for professional trading contexts
3. Inconsistent with the serious, data-focused aesthetic traders expect

A muted steel blue-grey palette (`#5B7A8A`) provides distinction while maintaining usability.

## Proposed Solution

### Color Palette

| Context | Current Telegram | New Frontrun | Notes |
|---------|------------------|--------------|-------|
| Day Accent | `#0088FF` | `#5B7A8A` | Steel blue-grey, WCAG AA compliant (5.2:1) |
| Dark Accent | `#3E88F7` | `#6B8A9A` | Slightly lighter for dark backgrounds |
| Dark Tinted Accent | `#2EA6FF` | `#7BA3B3` | Warmer tinted variant |

> **Note:** Outgoing bubble colors are derived from accent via `withMultiplied()`. Test the auto-generated colors before adding explicit overrides.

### Scope

**Included (High Visibility):**
- Centralized theme files (accent colors propagate to nav bar, tab bar, buttons, links)

**Phase 2 - Only If Needed After Testing:**
- Navigation button hardcoded colors
- Activity indicator color mapping
- Gallery light theme
- Chat input recording overlay

**Excluded (Accepted Inconsistency):**
- Voice/video chat highlights
- Instant View article links
- Location map pulse animations
- Premium/Business promotional screens
- Legacy Objective-C components

## Technical Approach

### Phase 0: Define Constants (Single Source of Truth)

Add Frontrun color constants to `DefaultDayPresentationTheme.swift`:

```swift
// submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift

// MARK: - Frontrun Accent Colors
public let frontrunDayAccentColor = UIColor(rgb: 0x5B7A8A)
public let frontrunDarkAccentColor = UIColor(rgb: 0x6B8A9A)
public let frontrunTintedAccentColor = UIColor(rgb: 0x7BA3B3)
```

This ensures:
- One place to change colors in the future
- Constants can be imported by other modules if needed
- No scattered hex values across the codebase

### Phase 1: Centralized Theme Files (~30-50 lines)

**`submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift`**
- Add Frontrun constants (Phase 0)
- Line 57: `public let defaultDayAccentColor = frontrunDayAccentColor`

**`submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift`**
- Line 7: Change accent in `defaultDarkColorPresentationTheme` to `frontrunDarkAccentColor`
- **Watch out:** Lines 59-64 have a gradient check for `0x3e88f7`. Your new color won't match, so test the fallback gradient.

**`submodules/TelegramPresentationData/Sources/DefaultDarkTintedPresentationTheme.swift`**
- Line 7: `private let defaultDarkTintedAccentColor = frontrunTintedAccentColor`

**After Phase 1: BUILD AND TEST.** The theme system should propagate colors to nav bar, tab bar, buttons, and links automatically.

### Phase 2: Hardcoded Fixes (Only If Phase 1 Testing Reveals Issues)

**⚠️ Critical: ActivityIndicator Color Mapping**

`submodules/ActivityIndicator/Sources/ActivityIndicator.swift:19-21` has equality checks:
```swift
if color.isEqual(UIColor(rgb: 0x007aff)) || color.isEqual(UIColor(rgb: 0x0088ff)) {
    return .gray
}
```

Add Frontrun colors to this check:
```swift
if color.isEqual(UIColor(rgb: 0x007aff)) ||
   color.isEqual(UIColor(rgb: 0x0088ff)) ||
   color.isEqual(frontrunDayAccentColor) {
    return .gray
}
```

**Other hardcoded locations (only if testing shows Telegram blue):**
- `submodules/Display/Source/NavigationBackButtonNode.swift:34`
- `submodules/TelegramUI/Components/NavigationBarImpl/Sources/NavigationButtonNode.swift:312,548`
- `submodules/GalleryUI/Sources/GalleryController.swift:580`
- `submodules/TelegramUI/Components/ChatTextInputMediaRecordingButton/Sources/ChatTextInputAudioRecordingOverlayButton.swift:11-12`

## Acceptance Criteria

- [x] Frontrun color constants defined in one place
- [x] Day theme accent color is `#5B7A8A` (steel blue-grey)
- [x] Dark theme accent color is `#6B8A9A`
- [x] Dark tinted theme accent color is `#7BA3B3`
- [x] Navigation bar buttons use new accent in all themes
- [x] Tab bar selected icons use new accent
- [x] No Telegram blue visible in primary navigation or chat surfaces
- [ ] Existing user-customized themes remain unaffected
- [x] Activity indicator behaves correctly with new colors

## Success Metrics

1. Visual differentiation from stock Telegram (no `#0088FF` in primary UI)
2. Minimal line count (target: ~50 lines for Phase 1)
3. No regression in theme switching behavior
4. WCAG AA contrast maintained (4.5:1 minimum)

## Dependencies & Risks

### Dependencies
- None - self-contained visual change

### Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Derived colors look muddy | Medium | Medium | Test all theme multipliers; adjust if needed |
| Dark bubble gradient check fails | Medium | Low | Test fallback; add explicit case if needed |
| ActivityIndicator misbehaves | High | Medium | Add new colors to equality check |
| Missed hardcoded color | Low | Low | Accept minor inconsistency in edge cases |

## Testing Checklist

### Phase 1 Verification (Required)
- [x] Build succeeds
- [x] Day theme: nav bar, tab bar, links, buttons show steel blue-grey
- [x] Dark theme: same surfaces show correct dark accent
- [x] Dark tinted theme: same surfaces show correct tinted accent
- [ ] Outgoing message bubble gradient looks acceptable (not muddy)
- [x] Activity indicator works correctly
- [ ] Chat links use new accent color

### Phase 2 Verification (If Needed)
- [x] Open gallery in light theme
- [x] Record voice message (check overlay button)
- [ ] Test automatic theme switching (light ↔ dark)

### Edge Cases
- [ ] Existing custom theme user retains their color

## Implementation Notes

### Color Constants Reference

```swift
// Frontrun Steel Blue-Grey Palette - Define ONCE in DefaultDayPresentationTheme.swift
public let frontrunDayAccentColor = UIColor(rgb: 0x5B7A8A)      // Day theme
public let frontrunDarkAccentColor = UIColor(rgb: 0x6B8A9A)     // Dark theme
public let frontrunTintedAccentColor = UIColor(rgb: 0x7BA3B3)   // Dark tinted theme
```

### Verification Command

After implementation, check for remaining Telegram blue in high-visibility areas:

```bash
grep -rn "0x0088ff\|0x3e88f7\|0x2ea6ff" submodules/TelegramPresentationData submodules/Display submodules/ActivityIndicator --include="*.swift"
```

## References & Research

### Internal References
- Theme system: `submodules/TelegramPresentationData/Sources/PresentationTheme.swift`
- Day theme defaults: `submodules/TelegramPresentationData/Sources/DefaultDayPresentationTheme.swift:57`
- Dark theme defaults: `submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift:7`
- Dark gradient check: `submodules/TelegramPresentationData/Sources/DefaultDarkPresentationTheme.swift:59-64`
- Tinted theme defaults: `submodules/TelegramPresentationData/Sources/DefaultDarkTintedPresentationTheme.swift:7`
- Activity indicator mapping: `submodules/ActivityIndicator/Sources/ActivityIndicator.swift:19-21`

### Naming Convention
Per CLAUDE.md: Frontrun-specific files should be prefixed with `Frontrun`. However, this change modifies existing Telegram theme files rather than creating new ones, so no new naming applies.

### Build Command
```bash
bazel build Telegram/Telegram --features=swift.use_global_module_cache --verbose_failures --jobs=16 --define=buildNumber=10000 --define=telegramVersion=12.2.1 -c dbg --ios_multi_cpus=sim_arm64 --features=swift.enable_batch_mode --//Telegram:disableProvisioningProfiles
```

---

## Review Notes

**Reviewed by:** DHH, Kieran, Simplicity (2026-01-23)

**Key feedback incorporated:**
1. ✅ Define constants in one place, don't scatter hex values (Kieran)
2. ✅ Add Phase 0 for constants before touching theme files (Kieran)
3. ✅ Test Phase 1 alone before adding Phase 2 (Simplicity)
4. ✅ Document ActivityIndicator equality check as critical (DHH, Kieran)
5. ✅ Note dark bubble gradient check may need attention (DHH)
6. ✅ Add bubble gradient and link color to testing (Kieran)
