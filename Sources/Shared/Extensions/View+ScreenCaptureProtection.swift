import SwiftUI

public struct ScreenCaptureProtectionModifier: ViewModifier {
    private let blurRadius: CGFloat

    public init(blurRadius: CGFloat = 8) {
        self.blurRadius = blurRadius
    }

    public func body(content: Content) -> some View {
        #if !os(watchOS)
        if #available(iOS 17, macCatalyst 17, *) {
            content.modifier(SceneCaptureBlur(blurRadius: blurRadius))
        } else {
            content.modifier(LegacyScreenCaptureBlur(blurRadius: blurRadius))
        }
        #else
        content
        #endif
    }

    #if !os(watchOS)
    /// Follows the capture state of the scene this view is in rather than of one global screen.
    @available(iOS 17, macCatalyst 17, *)
    private struct SceneCaptureBlur: ViewModifier {
        let blurRadius: CGFloat
        @Environment(\.isSceneCaptured) private var isSceneCaptured

        func body(content: Content) -> some View {
            content
                .blur(radius: isSceneCaptured ? blurRadius : 0)
                .animation(.easeInOut(duration: 0.2), value: isSceneCaptured)
        }
    }

    /// iOS 16 has no per-scene capture state, so the main screen is the only source there.
    private struct LegacyScreenCaptureBlur: ViewModifier {
        let blurRadius: CGFloat
        @State private var isScreenCaptured = false

        func body(content: Content) -> some View {
            content
                .blur(radius: isScreenCaptured ? blurRadius : 0)
                .animation(.easeInOut(duration: 0.2), value: isScreenCaptured)
                .onAppear {
                    isScreenCaptured = UIScreen.main.isCaptured
                }
                .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) {
                    if let screen = $0.object as? UIScreen {
                        isScreenCaptured = screen.isCaptured
                    }
                }
        }
    }
    #endif
}

public extension View {
    func screenCaptureProtected(blurRadius: CGFloat = 16) -> some View {
        modifier(ScreenCaptureProtectionModifier(blurRadius: blurRadius))
    }
}
