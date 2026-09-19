import SwiftUI

/// The navigation bar's subtitle, on the iOS versions that have one. The feature only opens on iOS 26
/// (see `AppLabsFeature`), so the empty branch is what keeps the view compiling for older targets.
struct NativeModalSubtitleModifier: ViewModifier {
    let subtitle: String?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle(subtitle ?? "")
        } else {
            content
        }
    }
}
