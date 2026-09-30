#if os(iOS)
import SFSafeSymbols
import Shared
import SwiftUI

/// The avatar menu's entries: Edit profile, then the other servers to switch to.
@available(iOS 26, macOS 26, *)
struct NativeTabBarProfileMenuItems: View {
    let viewModel: NativeTabBarViewModel
    let profile: MacSidebarItem

    var body: some View {
        Button {
            viewModel.open(profile)
        } label: {
            Label(L10n.TabBar.More.editProfile, systemSymbol: .personCropCircle)
        }
        Section(L10n.TabBar.More.otherServers) {
            ForEach(viewModel.otherServers, id: \.identifier) { server in
                Button {
                    viewModel.open(server: server)
                } label: {
                    Text(server.info.name)
                }
            }
        }
    }
}

@available(iOS 26, macOS 26, *)
#Preview {
    let viewModel = NativeTabBarViewModel.preview(additionalServers: [ServerFixture.withRemoteConnection])
    Menu {
        if let profile = viewModel.profileItem {
            NativeTabBarProfileMenuItems(viewModel: viewModel, profile: profile)
        }
    } label: {
        Text(viewModel.sidebar.server.info.name)
    }
}
#endif
