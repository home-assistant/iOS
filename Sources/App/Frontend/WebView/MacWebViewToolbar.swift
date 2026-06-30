import SFSafeSymbols
import Shared
import SwiftUI
import UIKit
#if targetEnvironment(macCatalyst)
import AppKit
#endif

struct MacWebViewToolbar: View {
    fileprivate enum Constants {
        static let leadingPadding: CGFloat = 80
        static let buttonHoverScale: CGFloat = 1.16
        static let buttonPressedScale: CGFloat = 0.90
        static let navigationShadowRadius: CGFloat = 2
        static let navigationShadowYOffset: CGFloat = 1
        static let toolbarIconSize: CGFloat = 12
        static let previewWidth: CGFloat = 520
        static let buttonScaleAnimationDuration: TimeInterval = 0.12
        static let navigationShadowColor = Color.black.opacity(0.18)
    }

    let server: Server
    weak var webViewController: WebViewController?

    private let macOS26StylingOverride: Bool?

    @StateObject private var serversObserver = ServersObserver()

    init(
        server: Server,
        webViewController: WebViewController?,
        macOS26StylingOverride: Bool? = nil
    ) {
        self.server = server
        self.webViewController = webViewController
        self.macOS26StylingOverride = macOS26StylingOverride
    }

    private var servers: [Server] {
        serversObserver.servers
    }

    private var usesMacOS26Styling: Bool {
        if let macOS26StylingOverride {
            return macOS26StylingOverride
        }

        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        HStack {
            leftButtons
            Spacer()
            rightButtons

            if servers.count > 1 {
                serverPicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding([.top, .trailing], DesignSystem.Spaces.half)
        .padding(.leading, Constants.leadingPadding)
    }

    private var leftButtons: some View {
        HStack {
            backForwardButtons

            toolbarButton(
                action: {
                    webViewController?.refresh()
                },
                accessibilityLabel: L10n.Watch.Settings.refresh,
                symbol: .arrowClockwise
            )
        }
    }

    @ViewBuilder
    private var backForwardButtons: some View {
        HStack(spacing: DesignSystem.Spaces.micro) {
            backButton()
            forwardButton()
        }
    }

    private func backButton() -> some View {
        toolbarButton(
            action: {
                webViewController?.goBack()
            },
            accessibilityLabel: L10n.Mac.Navigation.GoBack.accessibilityLabel,
            symbol: .chevronLeft
        )
    }

    private func forwardButton() -> some View {
        toolbarButton(
            action: {
                webViewController?.goForward()
            },
            accessibilityLabel: L10n.Mac.Navigation.GoForward.accessibilityLabel,
            symbol: .chevronRight
        )
    }

    private var rightButtons: some View {
        HStack {
            toolbarButton(
                action: {
                    webViewController?.copyCurrentSelectedContent()
                },
                accessibilityLabel: L10n.Mac.Copy.accessibilityLabel,
                symbol: .docOnDoc
            )

            toolbarButton(
                action: {
                    webViewController?.pasteContent()
                },
                accessibilityLabel: L10n.Mac.Paste.accessibilityLabel,
                symbol: .docOnClipboard
            )
            toolbarButton(
                action: {
                    webViewController?.openServerInSafari()
                },
                accessibilityLabel: L10n.Mac.OpenInSafari.accessibilityLabel,
                symbol: .safariFill
            )
        }
    }

    private var serverPicker: some View {
        Menu {
            ForEach(servers, id: \.identifier) { server in
                Button {
                    openServer(server)
                } label: {
                    if server.identifier == self.server.identifier {
                        Label(server.info.name, systemSymbol: .checkmark)
                    } else {
                        Text(server.info.name)
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spaces.micro) {
                Text(server.info.name)
                    .lineLimit(1)
                Image(systemSymbol: .chevronDown)
            }
        }
        .buttonStyle(ToolbarButtonStyle())
        .accessibilityLabel(L10n.WebView.ServerSelection.title)
        .accessibilityValue(server.info.name)
        .help(L10n.WebView.ServerSelection.title)
    }

    private func openServer(_ selectedServer: Server) {
        guard selectedServer.identifier != server.identifier else { return }
        webViewController?.openServer(selectedServer)
    }

    @ViewBuilder
    private func toolbarButton(
        action: @escaping () -> Void,
        accessibilityLabel: String,
        symbol: SFSymbol
    ) -> some View {
        Button(action: action) {
            Image(systemSymbol: symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.toolbarIconSize, height: Constants.toolbarIconSize)
        }
        .buttonStyle(ToolbarButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }
}

private struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .toolbarInteractiveStyle(isPressed: configuration.isPressed)
    }
}

private extension View {
    func toolbarInteractiveStyle(
        isPressed: Bool = false,
        verticalPadding: CGFloat = DesignSystem.Spaces.half
    ) -> some View {
        modifier(ToolbarInteractiveStyleModifier(isPressed: isPressed, verticalPadding: verticalPadding))
    }
}

private struct ToolbarInteractiveStyleModifier: ViewModifier {
    let isPressed: Bool
    let verticalPadding: CGFloat

    @State private var isHovering = false
    @State private var isCursorPushed = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .background(.regularMaterial, in: .capsule)
            .scaleEffect(scale)
            .contentShape(Rectangle())
            .animation(
                .easeInOut(duration: MacWebViewToolbar.Constants.buttonScaleAnimationDuration),
                value: isPressed
            )
            .animation(
                .easeInOut(duration: MacWebViewToolbar.Constants.buttonScaleAnimationDuration),
                value: isHovering
            )
            .onHover { handleHover($0) }
            .onDisappear {
                popCursorIfNeeded()
            }
    }

    private var scale: CGFloat {
        if isPressed {
            return MacWebViewToolbar.Constants.buttonPressedScale
        } else if isHovering {
            return MacWebViewToolbar.Constants.buttonHoverScale
        } else {
            return 1
        }
    }

    private func handleHover(_ inside: Bool) {
        isHovering = inside

        #if targetEnvironment(macCatalyst)
        if inside, !isCursorPushed {
            NSCursor.pointingHand.push()
            isCursorPushed = true
        } else if !inside {
            popCursorIfNeeded()
        }
        #endif
    }

    private func popCursorIfNeeded() {
        #if targetEnvironment(macCatalyst)
        guard isCursorPushed else { return }
        NSCursor.pop()
        isCursorPushed = false
        #endif
    }
}

#Preview("Mac Web View Toolbar") {
    MacWebViewToolbar(server: ServerFixture.standard, webViewController: nil)
        .padding()
        .frame(width: MacWebViewToolbar.Constants.previewWidth)
        .background(Color(uiColor: .systemBackground))
}

#Preview("Mac Web View Toolbar - Legacy Styling") {
    MacWebViewToolbar(
        server: ServerFixture.standard,
        webViewController: nil,
        macOS26StylingOverride: false
    )
    .padding()
    .frame(width: MacWebViewToolbar.Constants.previewWidth)
    .background(Color(uiColor: .systemBackground))
}
