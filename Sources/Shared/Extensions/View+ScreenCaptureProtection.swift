import SwiftUI

public struct ScreenCaptureProtectionModifier: ViewModifier {
    private let blurRadius: CGFloat
    @State private var isScreenCaptured = false

    public init(blurRadius: CGFloat = 8) {
        self.blurRadius = blurRadius
    }

    public func body(content: Content) -> some View {
        #if !os(watchOS)
        content
            .blur(radius: isScreenCaptured ? blurRadius : 0)
            .animation(.easeInOut(duration: 0.2), value: isScreenCaptured)
            .onAppear {
                isScreenCaptured = UIScreen.main.isCaptured
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                isScreenCaptured = UIScreen.main.isCaptured
            }
        #else
        content
        #endif
    }
}

public extension View {
    func screenCaptureProtected(blurRadius: CGFloat = 16) -> some View {
        modifier(ScreenCaptureProtectionModifier(blurRadius: blurRadius))
    }
}
