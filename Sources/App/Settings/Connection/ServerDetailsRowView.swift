import SFSafeSymbols
import Shared
import SwiftUI

/// The row at the top of a server's settings: who the server is and the details the user can
/// change, read-only, with a single Edit menu that picks which one to change. URLs render as pills
/// that open their editor on tap, or as an Add pill when the URL is not set.
struct ServerDetailsRowView: View {
    enum EditOption: Hashable, CaseIterable {
        case locationName
        case deviceName
        case internalURL
        case externalURL

        var title: String {
            switch self {
            case .locationName: return L10n.Settings.StatusSection.LocationNameRow.title
            case .deviceName: return L10n.SettingsDetails.General.DeviceName.title
            case .internalURL: return L10n.Settings.ConnectionSection.InternalBaseUrl.title
            case .externalURL: return L10n.Settings.ConnectionSection.ExternalBaseUrl.title
            }
        }

        var symbol: SFSymbol {
            switch self {
            case .locationName: return .house
            case .deviceName: return .iphone
            case .internalURL: return .wifi
            case .externalURL: return .globe
            }
        }

        var isURL: Bool {
            switch self {
            case .internalURL, .externalURL: return true
            case .locationName, .deviceName: return false
            }
        }
    }

    struct Detail: Identifiable {
        let option: EditOption
        let value: String?
        let isPlaceholder: Bool
        let isActive: Bool
        let symbol: SFSymbol?
        /// What Copy puts on the clipboard when it differs from `value`, such as the cloud pill's remote UI
        /// address behind its "Home Assistant Cloud" label.
        let copyValue: String?

        var id: EditOption { option }

        init(
            option: EditOption,
            value: String?,
            isPlaceholder: Bool = false,
            isActive: Bool = false,
            symbol: SFSymbol? = nil,
            copyValue: String? = nil
        ) {
            self.option = option
            self.value = value
            self.isPlaceholder = isPlaceholder
            self.isActive = isActive
            self.symbol = symbol
            self.copyValue = copyValue ?? (option.isURL && symbol == nil ? value : nil)
        }
    }

    private enum Constants {
        static let avatarSize: CGFloat = DesignSystem.Spaces.seven
    }

    /// Shared by the pill's tap menu and its long-press context menu. Copy only shows when there is an
    /// address to copy.
    struct URLPillMenuItems: View {
        let copyValue: String?
        let onEdit: () -> Void

        var body: some View {
            Button(action: onEdit) {
                Label(L10n.editLabel, systemSymbol: .pencil)
            }
            if let copyValue {
                Button {
                    UIPasteboard.general.string = copyValue
                } label: {
                    Label(L10n.copyLabel, systemSymbol: .docOnDoc)
                }
            }
        }
    }

    let serverName: String
    let userName: String
    let profilePicture: UIImage?
    let details: [Detail]
    /// Shows the Sync button mid-flight while the server's database refreshes.
    let isSyncing: Bool
    /// Lets the URL editor zoom out of the pill that opened it.
    let transitionNamespace: Namespace.ID?
    let onEdit: (EditOption) -> Void
    let onSync: () -> Void
    let onTroubleshoot: () -> Void
    /// Switches the app to this server; nil when there is nothing to switch from.
    let onOpen: (() -> Void)?
    /// Off for a read-only rendering such as a context-menu preview: no Open, Sync or Troubleshooting.
    var showsActions = true

    private var hasActiveURL: Bool {
        details.contains { $0.isActive && $0.value != nil }
    }

    private var hasAnyURL: Bool {
        details.contains { $0.option.isURL && $0.value != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                Group {
                    if let profilePicture {
                        Image(uiImage: profilePicture)
                            .resizable()
                    } else {
                        Circle()
                            .fill(.haPrimary)
                            .overlay(
                                Text(serverName.prefix(1).uppercased())
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            )
                    }
                }
                .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                    Text(serverName)
                        .font(.title3.bold())
                        .lineLimit(2)
                    if !userName.isEmpty {
                        Text(userName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: DesignSystem.Spaces.one)

                if showsActions, let onOpen {
                    Button(action: onOpen) {
                        Text(L10n.Settings.ConnectionSection.openServer)
                            .font(.subheadline.weight(.semibold))
                    }
                    .fixedSize()
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.haPrimary)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)

            Divider()

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
                ForEach(details) { detail in
                    VStack(
                        alignment: .leading,
                        spacing: detail.option.isURL ? DesignSystem.Spaces.one : DesignSystem.Spaces.half
                    ) {
                        let activeSuffix = L10n.Settings.ConnectionSection.UrlsHowItWorks.Active.header
                        Text(detail.isActive ? "\(detail.option.title) (\(activeSuffix))" : detail.option.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !detail.option.isURL {
                            Text(detail.value ?? "")
                                .font(.body)
                                .foregroundStyle(detail.isPlaceholder ? .tertiary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else if let value = detail.value {
                            Menu {
                                URLPillMenuItems(copyValue: detail.copyValue) { onEdit(detail.option) }
                            } label: {
                                HStack(spacing: DesignSystem.Spaces.one) {
                                    Image(systemSymbol: detail.symbol ?? detail.option.symbol)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.haPrimary)
                                    Text(value)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(detail.isActive ? Color.haPrimary : Color.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(.vertical, DesignSystem.Spaces.one)
                                .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                                .background(
                                    detail.isActive ? Color.haPrimaryLightFill : Color.haNeutralQuietFill,
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                URLPillMenuItems(copyValue: detail.copyValue) { onEdit(detail.option) }
                            }
                            .modify { view in
                                if #available(iOS 18.0, *), let transitionNamespace {
                                    view.matchedTransitionSource(id: detail.option, in: transitionNamespace)
                                } else {
                                    view
                                }
                            }
                        } else {
                            Button {
                                onEdit(detail.option)
                            } label: {
                                HStack(spacing: DesignSystem.Spaces.half) {
                                    Image(systemSymbol: .plus)
                                    Text(L10n.addButtonLabel)
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(.haPrimary)
                            .modify { view in
                                if #available(iOS 18.0, *), let transitionNamespace {
                                    view.matchedTransitionSource(id: detail.option, in: transitionNamespace)
                                } else {
                                    view
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spaces.two)

                    if detail.id != details.last?.id {
                        Divider()
                            .padding(.leading, DesignSystem.Spaces.two)
                    }
                }
            }

            if showsActions, hasActiveURL {
                Divider()

                HAProgressButton(
                    L10n.Settings.ConnectionSection.syncServer,
                    icon: .syncIcon,
                    state: isSyncing ? .inProgress : .idle
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSync()
                }
                .padding(.horizontal, DesignSystem.Spaces.two)
            } else if showsActions, hasAnyURL {
                Divider()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTroubleshoot()
                } label: {
                    Label(L10n.Settings.ConnectionSection.troubleshooting, systemSymbol: .exclamationmarkTriangle)
                }
                .buttonStyle(.warningButton)
                .padding(.horizontal, DesignSystem.Spaces.two)
            }
        }
        .padding(.vertical, DesignSystem.Spaces.two)
        .listRowInsets(EdgeInsets())
    }
}

extension ServerDetailsRowView {
    /// The details rows for `server` read straight from its stored info, for places that have no
    /// view model, such as the servers list's long-press preview.
    static func details(for server: Server) -> [Detail] {
        let info = server.info
        var connection = info.connection
        _ = connection.evaluateActiveURL()
        let deviceName: String? = info.setting(for: .overrideDeviceName)
        let usesCloud = connection.useCloud && connection.canUseCloud
        let internalURL = connection.address(for: .internal)?.absoluteString
        let externalURL = usesCloud
            ? AppConstants.homeAssistantLinkName
            : connection.address(for: .external)?.absoluteString
        return [
            .init(
                option: .deviceName,
                value: deviceName ?? Current.device.deviceName(),
                isPlaceholder: deviceName == nil
            ),
            .init(
                option: .internalURL,
                value: internalURL,
                isActive: connection.activeURLType == .internal && internalURL != nil
            ),
            .init(
                option: .externalURL,
                value: externalURL,
                isActive: (connection.activeURLType == .external || connection.activeURLType == .remoteUI)
                    && externalURL != nil,
                symbol: usesCloud ? .icloud : nil,
                copyValue: usesCloud ? connection.address(for: .remoteUI)?.absoluteString : externalURL
            ),
        ]
    }
}

#Preview {
    List {
        Section {
            ServerDetailsRowView(
                serverName: "Home",
                userName: "Bruno",
                profilePicture: nil,
                details: [
                    .init(option: .deviceName, value: "Bruno's iPhone", isPlaceholder: true),
                    .init(option: .internalURL, value: "http://homeassistant.local:8123", isActive: true),
                    .init(option: .externalURL, value: nil),
                ],
                isSyncing: false,
                transitionNamespace: nil,
                onEdit: { _ in },
                onSync: {},
                onTroubleshoot: {},
                onOpen: {}
            )
        }
    }
}
