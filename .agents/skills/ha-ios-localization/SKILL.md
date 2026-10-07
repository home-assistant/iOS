---
name: ha-ios-localization
description: Localization via SwiftGen-generated L10n accessors and the en.lproj .strings files. Use when adding or changing user-facing strings, working with the L10n/CoreStrings/FrontendStrings tables, or dealing with Lokalise-managed translations.
---

# Localization

## How Strings Work

1. **Add strings** to the English `.strings` file: `Sources/App/Resources/en.lproj/Localizable.strings`
2. **SwiftGen auto-generates** type-safe accessors in `Sources/Shared/Resources/Swiftgen/Strings.swift` when building the app
3. **Use generated accessors** via the `L10n` enum:

```swift
// In Localizable.strings:
"settings.title" = "Settings";
"sensor.name_%@" = "Sensor: %@";

// In Swift code (auto-generated):
let title = L10n.Settings.title
let name = L10n.Sensor.name("Temperature")
```

There are multiple string tables:
- `Localizable.strings` → `L10n` enum
- `Core.strings` → `CoreStrings` enum
- `Frontend.strings` → `FrontendStrings` enum

All string lookup flows through `Current.localized.string` which handles locale fallback.

> **Important**: Translations for other languages are managed externally via [Lokalise](https://lokalise.com/public/834452985a05254348aee2.46389241/). Only add/modify strings in the `en.lproj` files.
