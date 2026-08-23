import SFSafeSymbols
import Shared
import SwiftUI

/// Top row of the connection/re-authentication empty state, shared by `HomeAssistantStandByView` and
/// `WebViewEmptyStateView`: the style's accessories around the server selection.
struct WebViewEmptyStateHeader: View {
    static let accessorySize = CGSize(width: 44, height: 44)
    static let dismissTapThreshold = 5

    let style: WebViewEmptyStateStyle
    let server: Server
    let isLoading: Bool
    let showsServerSelection: Bool
    /// When the action buttons show the error details button in place of the secondary settings button,
    /// settings moves up into the leading accessory.
    let showsErrorDetailsButton: Bool
    let settingsAction: () -> Void
    let serverSelectionAction: (Server) -> Void
    let dismissAction: () -> Void

    /// Whether the empty-state header should render the server picker. Hidden on Catalyst (the Mac
    /// title bar owns server switching) and when there is nothing to switch to.
    static func showsServerSelection(
        style: WebViewEmptyStateStyle,
        serverCount: Int,
        isCatalyst: Bool
    ) -> Bool {
        style.showsServerPicker && serverCount > 1 && !isCatalyst
    }

    var body: some View {
        HStack {
            Accessory(
                accessory: leadingAccessory,
                isLoading: isLoading,
                settingsAction: settingsAction,
                dismissAction: dismissAction
            )
            Spacer()
            if showsServerSelection {
                if Current.isCatalyst {
                    Menu {
                        ForEach(Current.servers.all, id: \.identifier) { availableServer in
                            Button {
                                serverSelectionAction(availableServer)
                            } label: {
                                Label(availableServer.info.name, systemSymbol: symbol(for: availableServer))
                            }
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Image(systemSymbol: .serverRack)
                                .foregroundStyle(Color.haPrimary)
                            Text(server.info.name)
                                .font(.callout)
                                .lineLimit(1)
                            Image(systemSymbol: .chevronUpChevronDown)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DesignSystem.Spaces.two)
                        .padding(.vertical, DesignSystem.Spaces.one)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                } else {
                    ServerPickerView(server: server, onSelect: serverSelectionAction)
                        // Using .secondarySystemBackground to visually distinguish the server selection view
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            Accessory(
                accessory: style.trailingHeaderAccessory,
                isLoading: isLoading,
                settingsAction: settingsAction,
                dismissAction: dismissAction
            )
        }
        .padding()
    }

    private var leadingAccessory: WebViewEmptyStateStyle.HeaderAccessory {
        if style.showsSecondarySettingsButton, showsErrorDetailsButton {
            .settings
        } else {
            style.leadingHeaderAccessory
        }
    }

    private func symbol(for availableServer: Server) -> SFSymbol {
        availableServer.identifier == server.identifier ? .checkmark : .serverRack
    }

    private struct Accessory: View {
        private static let size = WebViewEmptyStateHeader.accessorySize

        let accessory: WebViewEmptyStateStyle.HeaderAccessory
        let isLoading: Bool
        let settingsAction: () -> Void
        let dismissAction: () -> Void

        @State private var dismissTapCount = 0

        var body: some View {
            switch accessory {
            case .none:
                Color.clear
                    .frame(width: Self.size.width, height: Self.size.height)
            case .settings:
                ModalReusableButton(
                    icon: .sfSymbol(.gearshape),
                    action: settingsAction
                )
                .accessibilityLabel(L10n.WebView.EmptyState.openSettingsButton)
            case .hiddenDismiss:
                Color.clear
                    .frame(width: Self.size.width, height: Self.size.height)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: registerDismissTap)
                    .accessibilityHidden(true)
            }
        }

        private func registerDismissTap() {
            dismissTapCount += 1
            guard dismissTapCount >= WebViewEmptyStateHeader.dismissTapThreshold else { return }
            dismissTapCount = 0
            dismissAction()
        }
    }
}

#Preview("Disconnected") {
    VStack {
        WebViewEmptyStateHeader(
            style: .disconnected,
            server: ServerFixture.standard,
            isLoading: true,
            showsServerSelection: true,
            showsErrorDetailsButton: false,
            settingsAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {}
        )
        Spacer()
    }
}

#Preview("Recovered Reauthentication") {
    VStack {
        WebViewEmptyStateHeader(
            style: .recoveredServerNeedingReauthentication,
            server: ServerFixture.standard,
            isLoading: false,
            showsServerSelection: false,
            showsErrorDetailsButton: false,
            settingsAction: {},
            serverSelectionAction: { _ in },
            dismissAction: {}
        )
        Spacer()
    }
}
