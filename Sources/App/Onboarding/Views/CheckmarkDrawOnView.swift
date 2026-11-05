import Shared
import SwiftUI
import UIKit

/// A checkmark that draws itself on, with a success haptic as it lands. Sized by the caller so it can
/// sit centered on an empty screen or take an illustration slot.
struct CheckmarkDrawOnView: View {
    let size: CGFloat
    let tint: Color
    let animated: Bool

    @State private var isActive: Bool

    init(size: CGFloat = 150, tint: Color = .haPrimary, animated: Bool = true) {
        self.size = size
        self.tint = tint
        self.animated = animated
        self._isActive = State(initialValue: animated)
    }

    var body: some View {
        Image(systemSymbol: .checkmarkCircle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .modify({ view in
                if #available(iOS 26.0, *) {
                    view.symbolEffect(.drawOn.individually, options: .speed(0.7), isActive: isActive)
                } else {
                    view
                }
            })
            .onAppear {
                guard animated else { return }
                isActive = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
    }
}

#Preview {
    CheckmarkDrawOnView()
}

#Preview("Settled") {
    CheckmarkDrawOnView(size: 96, tint: .haSuccessColor, animated: false)
}
