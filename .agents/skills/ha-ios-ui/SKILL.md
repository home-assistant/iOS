---
name: ha-ios-ui
description: "SwiftUI and UIKit UI conventions for Home Assistant iOS. Use when building views, choosing SwiftUI vs UIKit, bridging with embeddedInHostingController(), building reusable components in the HADesignSystem package, or following the one-struct-per-file, inline-body, and #Preview rules."
---

# UI Patterns

- **SwiftUI**: Preferred for new UI (settings, widgets)
- **UIKit**: Used in older code and where needed for platform APIs
- Use `View.embeddedInHostingController()` for SwiftUI-to-UIKit bridging
- View models are annotated with `@MainActor`
- Support both light and dark mode

## SwiftUI View Conventions

- **One struct per file**: whenever a new `View` struct is introduced, put it in its own file. Do not stack multiple view structs in one file.
- **Keep everything in `body`**: build the view's content inline inside `body`. Do not abstract portions out into separate reusable subviews (helper view structs or computed `some View` properties) just to break `body` up. Extract a new struct only when it is genuinely reused elsewhere, and when you do, it gets its own file (see above).
- **Always add a `#Preview`**: every SwiftUI view must ship with a preview so it can be checked quickly in Xcode.
- **Snapshot tests for new features**: any new feature that adds UI must include snapshot tests (see the `ha-ios-testing` skill).

## Design System & Reusable Components (`HADesignSystem`)

Reusable, app-agnostic UI lives in the **`HADesignSystem`** Swift package (`Sources/HADesignSystem`), **not** in `Sources/App`. `Shared` re-exports it (`@_exported import HADesignSystem`), so anything that already does `import Shared` sees the design system with no extra import.

- **Build new reusable components in the package, not the app.** Buttons, cards, inputs, controls, indicators, sheets, tokens, colors, and styles belong in `HADesignSystem`. Only genuinely one-off, app-specific views stay in `Sources/App`.
- **Keep package code app-agnostic.** No `Current` (the World), no `L10n` product copy, no `Server`/app models, no `MaterialDesignIcons`. Inject text, colors, icons, and data through `init` parameters instead. (This is why a few still-coupled components remain in `Shared` for now.)
- **Guard iOS-only code.** The package also builds for watchOS and SPM has no per-file target membership, so wrap components using iOS-only APIs (UIKit `UIScreen`, `UIColor.label`, etc.) in `#if !os(watchOS)`.
- **Semantic colors are code-defined** in `Color+Semantic.swift` on `ShapeStyle where Self == Color` (so both `Color.haPrimary` and `.foregroundStyle(.haPrimary)` resolve). Add new semantic colors there, not to an asset catalog.
- **Register every new component in `DesignSystemComponent`** (categorized via `ComponentCategory`) so it shows up in `ComponentsLibraryView`, the in-app components explorer/glossary.
