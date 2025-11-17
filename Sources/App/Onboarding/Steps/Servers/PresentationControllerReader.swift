import SwiftUI
import UIKit

// MARK: - Environment Key for Presentation Controller

/// Environment key for storing a reference to the presenting UIViewController.
///
/// This allows SwiftUI views to access their hosting UIViewController, which is useful
/// for presenting UIKit-based views (like authentication sheets, document pickers, etc.)
/// from within SwiftUI views.
private struct PresentationControllerKey: EnvironmentKey {
    static let defaultValue: UIViewController? = nil
}

public extension EnvironmentValues {
    /// The UIViewController that is hosting the current SwiftUI view.
    ///
    /// This value can be injected manually or automatically captured using `PresentationControllerReader`.
    ///
    /// Example usage:
    /// ```swift
    /// struct MyView: View {
    ///     @Environment(\.presentationController) var presentationController
    ///
    ///     var body: some View {
    ///         Button("Present Sheet") {
    ///             // Use presentationController to present UIKit views
    ///             viewModel.presentSheet(from: presentationController)
    ///         }
    ///     }
    /// }
    /// ```
    var presentationController: UIViewController? {
        get { self[PresentationControllerKey.self] }
        set { self[PresentationControllerKey.self] = newValue }
    }
}

// MARK: - Presentation Controller Reader

/// A SwiftUI view that captures the hosting UIViewController and makes it available to its content.
///
/// This view bridges the gap between SwiftUI and UIKit by providing access to the underlying
/// `UIViewController` that hosts the SwiftUI view hierarchy. This is particularly useful when
/// you need to present UIKit-based views (like `SFSafariViewController`, `UIDocumentPickerViewController`,
/// or custom authentication flows) from within SwiftUI.
///
/// ## Usage
///
/// Wrap your SwiftUI content with `PresentationControllerReader` and access the controller
/// through the closure parameter:
///
/// ```swift
/// struct MyView: View {
///     @ObservedObject var viewModel: MyViewModel
///
///     var body: some View {
///         PresentationControllerReader { controller in
///             VStack {
///                 Button("Authenticate") {
///                     viewModel.authenticate(presentingController: controller)
///                 }
///
///                 Button("Show Document Picker") {
///                     if let controller = controller {
///                         let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
///                         controller.present(picker, animated: true)
///                     }
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## How It Works
///
/// `PresentationControllerReader` uses `UIViewControllerRepresentable` to create a
/// `UIViewController` that becomes part of the SwiftUI view hierarchy. This controller
/// then hosts your SwiftUI content and passes itself as a parameter, allowing your
/// views to access it.
///
/// ## Mac Catalyst Considerations
///
/// This is especially useful for Mac Catalyst apps with multiple windows/scenes, where
/// you need to ensure that presented views appear on the correct window. Without capturing
/// the correct presentation controller, views might be presented on the wrong window.
///
/// ## Alternative: Environment Value
///
/// If your hosting controller manually injects itself into the environment (like
/// `OnboardingSceneDelegate` does), you can access it via the environment instead:
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.presentationController) var presentationController
///
///     var body: some View {
///         Button("Do Something") {
///             viewModel.doSomething(presentingController: presentationController)
///         }
///     }
/// }
/// ```
struct PresentationControllerReader<Content: View>: UIViewControllerRepresentable {
    /// A closure that receives the hosting UIViewController and returns SwiftUI content.
    let content: (UIViewController?) -> Content

    /// Creates a new presentation controller reader with the specified content.
    ///
    /// - Parameter content: A closure that takes an optional UIViewController and returns
    ///   the SwiftUI view content. The controller parameter will be `nil` until the view
    ///   is loaded, then will contain the hosting view controller.
    init(@ViewBuilder content: @escaping (UIViewController?) -> Content) {
        self.content = content
    }

    func makeUIViewController(context: Context) -> PresentationControllerReaderViewController<Content> {
        PresentationControllerReaderViewController(content: content)
    }

    func updateUIViewController(
        _ uiViewController: PresentationControllerReaderViewController<Content>,
        context: Context
    ) {
        uiViewController.updateContent(content)
    }
}

// MARK: - Presentation Controller Reader View Controller

/// The UIViewController that hosts SwiftUI content for `PresentationControllerReader`.
///
/// This controller embeds a `UIHostingController` and passes itself as a parameter
/// to the SwiftUI content, enabling the SwiftUI views to access their hosting controller.
///
/// - Note: This class is not intended to be used directly. Use `PresentationControllerReader` instead.
class PresentationControllerReaderViewController<Content: View>: UIViewController {
    private var content: (UIViewController?) -> Content
    private var hostingController: UIHostingController<Content>?

    init(content: @escaping (UIViewController?) -> Content) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateContent(content)
    }

    /// Updates the SwiftUI content being displayed.
    ///
    /// This method creates or updates the hosting controller with new content,
    /// passing `self` as the presentation controller parameter.
    ///
    /// - Parameter content: A closure that receives this view controller and returns SwiftUI content.
    func updateContent(_ content: @escaping (UIViewController?) -> Content) {
        self.content = content

        let rootView = content(self)

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hostingController.didMove(toParent: self)
            self.hostingController = hostingController
        }
    }
}
