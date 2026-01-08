import SwiftUI

/// Extracting Main Window to retreive the window scene and create the overlay window for our dynamic island based
/// toasts!
@available(iOS 18, *)
struct WindowExtractor: UIViewRepresentable {
    var result: (UIWindow) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let window = view.window {
                result(window)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
