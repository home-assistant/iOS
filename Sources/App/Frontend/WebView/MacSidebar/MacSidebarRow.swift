import HAKit
import Shared
import SwiftUI

/// A compact macOS-style sidebar row: accent icon, single-line title, subtle rounded selection and
/// hover fills so the icon stays visible when selected. Used for both the scrolling panel list and the
/// rows pinned below it (Settings, Notifications, Profile).
struct MacSidebarRow: View {
    /// The edit-mode control shown at the trailing edge, like the macOS sidebar editors.
    enum Accessory {
        case hide
        case show
    }

    private enum Constants {
        static let iconSize: CGFloat = 18
        static let rowHeight: CGFloat = 32
        static let pinnedRowHeight: CGFloat = 40
        static let selectedFillOpacity: CGFloat = 0.12
        static let badgeMinWidth: CGFloat = 28
    }

    let item: MacSidebarItem
    let isSelected: Bool
    let server: Server
    let user: HAResponseCurrentUser?
    var isPinned = false
    var accessory: Accessory?
    var onAccessoryTap: (() -> Void)?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spaces.one) {
                if item.kind == .profile {
                    MacSidebarAvatarView(server: server, title: item.title, user: user, size: Constants.iconSize)
                } else {
                    Image(uiImage: item.icon.image(
                        ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                        color: .label
                    ))
                    .renderingMode(.template)
                    .foregroundStyle(Color.haPrimary)
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                }
                Text(item.title)
                    .lineLimit(1)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
                if item.badge > 0 {
                    Text(item.badge, format: .number)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.vertical, DesignSystem.Spaces.micro)
                        .frame(minWidth: Constants.badgeMinWidth)
                        .background(Capsule().fill(Color.haPrimary))
                }
                if let accessory {
                    Button {
                        onAccessoryTap?()
                    } label: {
                        Image(systemSymbol: accessory == .hide ? .minusCircleFill : .plusCircleFill)
                            .font(.body)
                            .foregroundStyle(accessory == .hide ? Color.red : Color.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessory == .hide ? L10n.Mac.Sidebar.hide : L10n.Mac.Sidebar.show)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.one)
            .frame(height: isPinned ? Constants.pinnedRowHeight : Constants.rowHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one, style: .continuous)
                    .fill(fillColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    /// Hover uses the frontend's translucent primary tint so the sidebar reads like the web one.
    private var fillColor: Color {
        if isSelected {
            return Color.primary.opacity(Constants.selectedFillOpacity)
        } else if isHovering {
            return Color.haPrimaryLightFill
        } else {
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.micro) {
        MacSidebarRow(
            item: .init(id: "home", kind: .panel(path: "/home"), title: "Overview", icon: .viewDashboardIcon),
            isSelected: true,
            server: ServerFixture.standard,
            user: nil
        ) {}
        MacSidebarRow(
            item: .init(id: "config", kind: .panel(path: "/config"), title: "Settings", icon: .cogIcon),
            isSelected: false,
            server: ServerFixture.standard,
            user: nil,
            isPinned: true
        ) {}
        MacSidebarRow(
            item: .init(id: "notifications", kind: .notifications, title: "Notifications", icon: .bellIcon, badge: 3),
            isSelected: false,
            server: ServerFixture.standard,
            user: nil
        ) {}
        MacSidebarRow(
            item: .init(id: "energy", kind: .panel(path: "/energy"), title: "Energy", icon: .lightningBoltIcon),
            isSelected: false,
            server: ServerFixture.standard,
            user: nil,
            accessory: .hide
        ) {}
    }
    .padding()
    .frame(width: 240)
}
