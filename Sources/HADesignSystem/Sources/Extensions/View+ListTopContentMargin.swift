import Foundation
import SwiftUI

/// Insets the top of a `List`'s content, back-deploying `contentMargins` to iOS 16.
///
/// Frontend counterpart: none — a SwiftUI plumbing helper, not a design decision.
public extension View {
    func listTopContentMargin(_ length: CGFloat = DesignSystem.Spaces.half) -> some View {
        modify { view in
            if #available(iOS 17.0, watchOS 10.0, *) {
                view.contentMargins(.top, length)
            } else {
                view
            }
        }
    }
}
