import SFSafeSymbols
import Shared
import SwiftUI

/// The macOS (Catalyst) title-bar buttons, rendered in SwiftUI and layered over the top of `HomeAssistantView`.
/// Replaces the former UIKit `StatusBarButtonsConfigurator`. Driven by
/// `WebFrontendOverlayState.MacStatusBarButtonsContent`, which the Catalyst `WebViewController` publishes.
///
/// Layout mirrors the old UIKit toolbar: navigation controls (open-in-Safari, the back/forward pill, reload)
/// lead — inset to clear the window traffic-light controls — with copy/paste and the server picker trailing.
/// macOS 26+ gets a Liquid Glass treatment; older systems fall back to a solid fill.
struct MacStatusBarButtonsView: View {
    #if DEBUG
    /// Styling mode for debugging (only honoured in DEBUG builds).
    enum StylingMode {
        case automatic // Use system version detection
        case forceMacOS26 // Force macOS 26 glass styling
        case forceLegacy // Force legacy solid styling
    }

    static var debugStylingMode: StylingMode = .automatic
    #endif

    private enum Constants {
        static let itemSize: CGFloat = 20
        static let iconPointSize: CGFloat = 13
        static let cornerRadius: CGFloat = 10
        static let macOS26BarHeight: CGFloat = 30
        static let legacyBarHeight: CGFloat = 27
        /// Leading inset so the navigation controls clear the window traffic-light controls.
        static let macOS26LeadingInset: CGFloat = 78
        static let legacyLeadingInset: CGFloat = 68
        static let safariBadgeSize: CGFloat = 14
        static let safariIconSize: CGFloat = 7
        static let safariCornerRadius: CGFloat = 6
    }

    let content: WebFrontendOverlayState.MacStatusBarButtonsContent

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            openInSafariButton
            navigationPill
            circleIconButton(symbol: .arrowClockwise, accessibilityLabel: L10n.Menu.View.reloadPage) {
                content.refresh()
            }

            Spacer(minLength: DesignSystem.Spaces.one)

            circleIconButton(symbol: .docOnDoc, accessibilityLabel: L10n.Mac.Copy.accessibilityLabel) {
                content.copy()
            }
            circleIconButton(symbol: .docOnClipboard, accessibilityLabel: L10n.Mac.Paste.accessibilityLabel) {
                content.paste()
            }

            if content.servers.count > 1 {
                serverPicker
            }
        }
        .tint(Color(uiColor: .label))
        .padding(.leading, leadingInset)
        .padding(.trailing, DesignSystem.Spaces.half)
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
    }

    // MARK: - Buttons

    private var openInSafariButton: some View {
        Button(action: content.openInSafari) {
            Image(.compass)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: Constants.safariIconSize, height: Constants.safariIconSize)
                .foregroundStyle(Color.haPrimary)
                .frame(width: Constants.safariBadgeSize, height: Constants.safariBadgeSize)
                .background(.white, in: RoundedRectangle(cornerRadius: Constants.safariCornerRadius))
                .shadow(color: .black.opacity(0.7), radius: 0.5)
                .frame(width: Constants.itemSize, height: Constants.itemSize)
        }
        .buttonStyle(.plain)
        .itemContainer(useMacOS26Styling: useMacOS26Styling, cornerRadius: Constants.cornerRadius)
    }

    private var navigationPill: some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            pillButton(symbol: .chevronLeft, accessibilityLabel: L10n.Mac.Navigation.GoBack.accessibilityLabel) {
                content.goBack()
            }
            pillButton(symbol: .chevronRight, accessibilityLabel: L10n.Mac.Navigation.GoForward.accessibilityLabel) {
                content.goForward()
            }
        }
        .padding(.horizontal, DesignSystem.Spaces.half)
        .frame(height: Constants.itemSize)
        .itemContainer(useMacOS26Styling: useMacOS26Styling, cornerRadius: Constants.cornerRadius)
    }

    private var serverPicker: some View {
        Menu {
            Section(L10n.WebView.ServerSelection.title) {
                ForEach(content.servers, id: \.identifier) { server in
                    Button(server.info.name) { content.openServer(server) }
                }
            }
        } label: {
            Text(content.server.info.name)
                .lineLimit(1)
                .foregroundStyle(Color(uiColor: .label))
                .padding(.horizontal, DesignSystem.Spaces.one)
                .frame(height: Constants.itemSize)
        }
        .fixedSize()
        .itemContainer(useMacOS26Styling: useMacOS26Styling, cornerRadius: Constants.cornerRadius)
    }

    /// A bare button (no own background) for the back/forward pill.
    private func pillButton(
        symbol: SFSymbol,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemSymbol: symbol)
                .font(.system(size: Constants.iconPointSize, weight: .regular))
                .frame(width: Constants.iconPointSize, height: Constants.itemSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// An icon button wrapped in its own circular container (safari/reload/copy/paste share this).
    private func circleIconButton(
        symbol: SFSymbol,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemSymbol: symbol)
                .font(.system(size: Constants.iconPointSize, weight: .regular))
                .frame(width: Constants.itemSize, height: Constants.itemSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .itemContainer(useMacOS26Styling: useMacOS26Styling, cornerRadius: Constants.cornerRadius)
    }

    // MARK: - Styling

    private var barHeight: CGFloat {
        useMacOS26Styling ? Constants.macOS26BarHeight : Constants.legacyBarHeight
    }

    private var leadingInset: CGFloat {
        useMacOS26Styling ? Constants.macOS26LeadingInset : Constants.legacyLeadingInset
    }

    /// Whether to use macOS 26 (Liquid Glass) styling — respects the debug toggle in DEBUG builds.
    private var useMacOS26Styling: Bool {
        #if DEBUG
        switch Self.debugStylingMode {
        case .automatic:
            break // Fall through to system detection
        case .forceMacOS26:
            return true
        case .forceLegacy:
            return false
        }
        #endif

        if #available(macOS 26.0, *) {
            return true
        } else {
            return false
        }
    }
}

private extension View {
    /// Wraps a status-bar item in its container background: Liquid Glass on macOS 26+, otherwise a solid
    /// `systemGray5` fill — matching the old UIKit `applyGlassEffect` / `containerBackgroundColor` styling.
    @ViewBuilder
    func itemContainer(useMacOS26Styling: Bool, cornerRadius: CGFloat) -> some View {
        if useMacOS26Styling, #available(macOS 26.0, iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
