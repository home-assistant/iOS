import SFSafeSymbols
import Shared
import SwiftUI

struct WebViewEmptyStateServerLabel: View {
    static let avatarSize: CGFloat = 28

    let server: Server

    @State private var profilePicture: UIImage?
    @State private var userName: String?

    init(server: Server, profilePicture: UIImage? = nil, userName: String? = nil) {
        self.server = server
        _profilePicture = State(initialValue: profilePicture)
        _userName = State(initialValue: userName)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            avatar
                .accessibilityHidden(true)
            Text(server.info.name)
                .font(.callout)
                .lineLimit(1)
            Image(systemSymbol: .chevronUpChevronDown)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, showsAvatar ? DesignSystem.Spaces.one : DesignSystem.Spaces.two)
        .padding(.trailing, DesignSystem.Spaces.two)
        .frame(height: WebViewEmptyStateHeader.accessorySize.height)
        .haGlassBackground(in: Capsule())
        .contentShape(Capsule())
        .onAppear(perform: loadCachedProfile)
    }

    @ViewBuilder
    private var avatar: some View {
        if let profilePicture {
            Image(uiImage: profilePicture)
                .resizable()
                .scaledToFill()
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .clipShape(Circle())
        } else if let initial = userName?.first {
            Text(String(initial).uppercased())
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .background(Color.haPrimary, in: Circle())
        }
    }

    private var showsAvatar: Bool {
        profilePicture != nil || userName?.first != nil
    }

    private func loadCachedProfile() {
        guard let api = Current.api(for: server) else { return }
        api.cachedProfilePicture { profilePicture = $0 ?? profilePicture }
        api.cachedProfileName { userName = $0 ?? userName }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        WebViewEmptyStateServerLabel(server: ServerFixture.standard, userName: "Bruno")
        WebViewEmptyStateServerLabel(
            server: ServerFixture.standard,
            profilePicture: UIImage(systemSymbol: .personCircleFill)
        )
        WebViewEmptyStateServerLabel(server: ServerFixture.standard)
    }
}
