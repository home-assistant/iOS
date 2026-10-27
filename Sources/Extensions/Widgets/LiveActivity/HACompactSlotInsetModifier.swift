#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

/// Insets a compact Dynamic Island slot from the island's rounded end. A narrow island (iPhone Duo,
/// landscape, or one shared with another activity) gives the slot a 28pt circle instead, where the
/// inset would push the content off its centre, so it is dropped there.
struct HACompactSlotInsetModifier: ViewModifier {
    let edge: Edge.Set

    @Environment(\.haIsDynamicIslandLimitedInWidth) private var isLimitedInWidth

    func body(content: Content) -> some View {
        content
            .padding(edge, isLimitedInWidth ? 0 : DesignSystem.Spaces.half)
    }
}
#endif
