import SwiftUI

/// Extracting Main Window to retrieve the window scene and create the overlay window for our dynamic island based
/// toasts!
@available(iOS 18, *)
public struct WindowExtractor: UIViewRepresentable {
    public var result: (UIWindow) -> Void
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let window = view.window {
                result(window)
            }
        }
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
