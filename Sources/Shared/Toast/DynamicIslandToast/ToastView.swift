import SFSafeSymbols
import SwiftUI
import UIKit

public extension View {
    /// Renders the currently presented `ToastPresenter.shared` toast as a top overlay. Attach once at
    /// the app root. The overlay is non-interactive, so it never blocks touches to the content beneath.
    @ViewBuilder
    func toastOverlay() -> some View {
        if #available(iOS 18, *) {
            modifier(ToastOverlayModifier())
        } else {
            self
        }
    }
}

@available(iOS 18, *)
private struct ToastOverlayModifier: ViewModifier {
    @ObservedObject private var presenter = ToastPresenter.shared

    func body(content: Content) -> some View {
        content
            .background(ToastWindowInstaller(isPresenting: presenter.toast != nil))
    }
}

@available(iOS 18, *)
private struct ToastWindowInstaller: UIViewRepresentable {
    let isPresenting: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.setPresenting(isPresenting)
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window?.windowScene)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setPresenting(isPresenting)
        DispatchQueue.main.async {
            context.coordinator.attach(to: uiView.window?.windowScene)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        /// Long enough for `ToastView`'s dismissal animation to play out before the window goes away.
        private static let hideDelay: TimeInterval = 0.6

        private weak var windowScene: UIWindowScene?
        private var toastWindow: ToastWindow?
        private var hostingController: ToastHostingController?
        private var isPresenting = false
        private var hideWorkItem: DispatchWorkItem?

        func attach(to windowScene: UIWindowScene?) {
            guard let windowScene else { return }
            guard self.windowScene !== windowScene else { return }

            self.windowScene = windowScene

            let hostingController = ToastHostingController(rootView: ToastWindowContent())
            hostingController.view.backgroundColor = .clear
            hostingController.statusBarHiddenWhenIdle = statusBarHidden(in: windowScene)

            let toastWindow = ToastWindow(windowScene: windowScene)
            toastWindow.rootViewController = hostingController
            toastWindow.windowLevel = .alert + 1
            toastWindow.backgroundColor = .clear
            toastWindow.isHidden = !isPresenting

            self.hostingController = hostingController
            self.toastWindow = toastWindow
        }

        /// The topmost visible window owns status-bar appearance for the whole scene, so this one exists
        /// only while a toast does: left visible it would override kiosk mode's "hide status bar" and the
        /// full-screen setting with its own status-bar preference.
        func setPresenting(_ presenting: Bool) {
            hideWorkItem?.cancel()
            hideWorkItem = nil

            guard !presenting else {
                isPresenting = true
                hostingController?.statusBarHiddenWhenIdle = statusBarHidden(in: windowScene)
                toastWindow?.isHidden = false
                hostingController?.setNeedsStatusBarAppearanceUpdate()
                return
            }

            guard isPresenting else { return }

            let hideWorkItem = DispatchWorkItem { [weak self] in
                self?.isPresenting = false
                self?.toastWindow?.isHidden = true
            }
            self.hideWorkItem = hideWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.hideDelay, execute: hideWorkItem)
        }

        /// Read while the toast window is off screen, so it reflects what the app itself wants.
        private func statusBarHidden(in windowScene: UIWindowScene?) -> Bool {
            windowScene?.statusBarManager?.isStatusBarHidden ?? false
        }
    }

    /// In compact-width layouts the toast is drawn over the status bar / Dynamic Island, so it hides the
    /// status bar while it shows. In regular-width layouts it sits below the status bar and leaves it
    /// exactly as the app had it.
    private final class ToastHostingController: UIHostingController<ToastWindowContent> {
        var statusBarHiddenWhenIdle = false

        override var prefersStatusBarHidden: Bool {
            traitCollection.horizontalSizeClass == .compact ? true : statusBarHiddenWhenIdle
        }
    }
}

@available(iOS 18, *)
private final class ToastWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

@available(iOS 18, *)
private struct ToastWindowContent: View {
    @ObservedObject private var presenter = ToastPresenter.shared

    var body: some View {
        ToastView(toast: presenter.toast, isExpanded: presenter.toast != nil)
            .allowsHitTesting(false)
    }
}

// Animation adapted from Kavsoft's SwiftUI Dynamic Island toast:
// https://www.patreon.com/posts/swiftui-dynamic-147414349
@available(iOS 18, *)
public struct ToastView: View {
    public let toast: Toast?
    public let isExpanded: Bool

    public init(toast: Toast?, isExpanded: Bool) {
        self.toast = toast
        self.isExpanded = isExpanded
    }

    public var body: some View {
        GeometryReader {
            let safeArea = $0.safeAreaInsets
            let size = $0.size

            /// Dynamic Island
            let haveDynamicIsland: Bool = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = 11 + max(safeArea.top - 59, 0)

            /// Expanded Properties
            let maxToastWidth: CGFloat = 400
            let expandedWidth = min(size.width - 20, maxToastWidth)
            let expandedHeight: CGFloat = haveDynamicIsland ? 90 : 70
            let scaleX: CGFloat = isExpanded ? 1 : (dynamicIslandWidth / expandedWidth)
            let scaleY: CGFloat = isExpanded ? 1 : (dynamicIslandHeight / expandedHeight)

            ZStack {
                Group {
                    if #available(iOS 26.0, *) {
                        ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
                            .fill(.black)
                    } else {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.black)
                    }
                }
                .overlay {
                    ToastContent(haveDynamicIsland)
                        /// Keeping the exact expanded size and using the scale to shrink and fit
                        /// Avoids any text wraps and other such things!
                        .frame(width: expandedWidth, height: expandedHeight)
                        .scaleEffect(x: scaleX, y: scaleY)
                }
                .frame(
                    width: isExpanded ? expandedWidth : dynamicIslandWidth,
                    height: isExpanded ? expandedHeight : dynamicIslandHeight
                )
                .offset(
                    y: haveDynamicIsland ? topOffset : (isExpanded ? safeArea.top + 10 : -80)
                )
                /// For Non Dynamic Island Based Phones!
                .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
                /// For Dynamic Island Based Phones!
                /// Showing capsule when the effect is active and hiding it when it's not
                .animation(.linear(duration: 0.02).delay(isExpanded ? 0 : 0.28)) { content in
                    content
                        .opacity(haveDynamicIsland ? isExpanded ? 1 : 0 : 1)
                }
                .geometryGroup()
                .contentShape(.rect)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }

    /// Toast View Content
    @ViewBuilder
    func ToastContent(_ haveDynamicIsland: Bool) -> some View {
        if let toast {
            HStack(spacing: 10) {
                Image(systemSymbol: toast.symbol)
                    .font(toast.symbolFont)
                    .foregroundStyle(toast.symbolForegroundStyle.0, toast.symbolForegroundStyle.1)
                    /// Optional: .symbolEffect(.wiggle, value: isExpanded)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    if haveDynamicIsland {
                        Spacer(minLength: 0)
                    }

                    Text(toast.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(toast.message)
                        .font(.caption)
                        .foregroundStyle(.white.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, haveDynamicIsland ? 12 : 0)
                .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .compositingGroup()
            .blur(radius: isExpanded ? 0 : 5)
            .opacity(isExpanded ? 1 : 0)
        }
    }
}
