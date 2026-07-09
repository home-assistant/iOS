---
name: ha-ios-ui
description: "SwiftUI and UIKit UI conventions for Home Assistant iOS. Use when building views, choosing SwiftUI vs UIKit, bridging with embeddedInHostingController(), or following the one-struct-per-file, inline-body, and #Preview rules."
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
