import Foundation
import SwiftUI

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
