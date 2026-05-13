import Shared
import SwiftUI

extension View {
    @ViewBuilder
    func macOnboardingSheetFrame(minWidth: CGFloat, minHeight: CGFloat) -> some View {
        if Current.isCatalyst {
            frame(minWidth: minWidth, minHeight: minHeight)
        } else {
            self
        }
    }
}
