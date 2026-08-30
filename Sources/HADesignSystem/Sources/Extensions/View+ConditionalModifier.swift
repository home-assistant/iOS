import Foundation
import SwiftUI

/// Applies a modifier only when it resolves to something, which is how this package gates
/// availability-limited APIs without duplicating a view hierarchy.
///
/// Frontend counterpart: none — a SwiftUI plumbing helper, not a design decision.
public extension View {
    @ViewBuilder
    func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
}
