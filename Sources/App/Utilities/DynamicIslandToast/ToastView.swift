import SwiftUI

@available(iOS 18, *)
extension View {
    @ViewBuilder
    func dynamicIslandToast(isPresented: Binding<Bool>, value: Toast) -> some View {
        modifier(
            DynamicIslandToastViewModifier(
                isPresented: isPresented,
                value: value
            )
        )
    }
}

// Code snippet from Kavsoft, go support the creator if you like it:
// https://www.patreon.com/posts/swiftui-dynamic-147414349
/// Helper View Modifier
@available(iOS 18, *)
struct DynamicIslandToastViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var value: Toast
    /// View Properties
    @State private var overlayWindow: PassThroughWindow?
    @State private var overlayController: ToastHostingController?
    func body(content: Content) -> some View {
        content
            .background(WindowExtractor { mainWindow in
                createOverlayWindow(mainWindow)
            })
            .onChange(of: isPresented, initial: true) { _, newValue in
                guard let overlayWindow else { return }
                if newValue {
                    /// Setting Current Toast
                    overlayWindow.toast = value
                }

                overlayWindow.isPresented = newValue
                /// Updating Status Bar
                overlayController?.isStatusBarHidden = newValue
            }
            /// If the toast is closed outside we need to update the isPresented Property as well!
            .onChange(of: overlayWindow?.isPresented) { _, newValue in
                if let newValue, let overlayWindow,
                   overlayWindow.toast?.id == value.id, newValue != isPresented {
                    isPresented = false
                }

                /// Add More Logic according to your needs!
            }
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard let windowScene = mainWindow.windowScene else { return }

        if let window = windowScene.windows.first(where: { $0.tag == 1009 }) as? PassThroughWindow {
            print("Using Already Existing Window!")
            overlayWindow = window
            overlayController = window.rootViewController as? ToastHostingController
        } else {
            let overlayWindow = PassThroughWindow(windowScene: windowScene)
            overlayWindow.backgroundColor = .clear
            overlayWindow.isHidden = false
            overlayWindow.isUserInteractionEnabled = true
            overlayWindow.tag = 1009
            createRootController(overlayWindow)

            self.overlayWindow = overlayWindow
        }
    }

    private func createRootController(_ window: PassThroughWindow) {
        let hostingController = ToastHostingController(
            rootView: ToastView(window: window)
        )

        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController

        overlayController = hostingController
    }
}

@available(iOS 18, *)
struct ToastView: View {
    var window: PassThroughWindow
    var body: some View {
        GeometryReader {
            let safeArea = $0.safeAreaInsets
            let size = $0.size

            /// Dynamic Island
            let haveDynamicIsland: Bool = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = 11 + max(safeArea.top - 59, 0)

            /// Expanded Properties
            let expandedWidth = size.width - 20
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
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.height < 0 {
                            /// Dismiss
                            window.isPresented = false
                        }
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }

    /// Toast View Content
    @ViewBuilder
    func ToastContent(_ haveDynamicIsland: Bool) -> some View {
        if let toast = window.toast {
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

    var isExpanded: Bool {
        window.isPresented
    }
}
