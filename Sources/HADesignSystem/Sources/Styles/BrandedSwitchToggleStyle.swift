import SwiftUI

#if os(iOS)
/// The app-wide switch style: the standard switch tinted with the Home Assistant brand color.
/// Applied once at the SwiftUI hosting seams (`embeddedInHostingController`, the scene roots) so
/// every toggle picks it up without per-view styling — `UISwitch.appearance()` no longer reaches
/// SwiftUI toggles, which stopped being UISwitch-backed.
///
/// Frontend counterpart: `ha-switch`, which is likewise the platform's switch in brand colours
/// rather than a switch drawn from scratch.
public struct BrandedSwitchToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        // The explicit inner `.switch` style terminates style resolution, so re-wrapping the
        // configuration in a Toggle doesn't recurse into this style.
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(.haPrimary)
    }
}

public extension ToggleStyle where Self == BrandedSwitchToggleStyle {
    static var haStyle: BrandedSwitchToggleStyle { BrandedSwitchToggleStyle() }
}

extension BrandedSwitchToggleStyle: FrontendComponent {
    public static var frontendComponentName: String { "ha-switch" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
