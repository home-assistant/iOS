import SFSafeSymbols
import Shared
import SwiftUI

/// The settings gear at the trailing end of the More tab's bar: Home Assistant Settings for those who can open
/// it, otherwise the app's own settings.
@available(iOS 26, *)
struct NativeTabBarSettingsToolbarItem: ToolbarContent {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    let viewModel: NativeTabBarViewModel
    let appSettingsTransitionID: String
    let transitionNamespace: Namespace.ID?
    let appSettingsPresenter: AppSettingsPresenter?

    private var settingsIcon: FrontendIcon {
        viewModel.settingsItem?.icon ?? .material(.cogIcon)
    }

    var body: some ToolbarContent {
        if let transitionNamespace {
            settingsItem.matchedTransitionSource(id: appSettingsTransitionID, in: transitionNamespace)
        } else {
            settingsItem
        }
    }

    private var settingsItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.openSettings(using: appSettingsPresenter, zoomingFrom: appSettingsTransitionID)
            } label: {
                Label {
                    Text(L10n.Mac.Sidebar.settings)
                } icon: {
                    Image(uiImage: settingsIcon.image(ofSize: Constants.iconSize, color: .label))
                        .renderingMode(.template)
                }
            }
        }
    }
}

@available(iOS 26, *)
#Preview {
    NavigationStack {
        Color.clear
            .toolbar {
                NativeTabBarSettingsToolbarItem(
                    viewModel: .preview(),
                    appSettingsTransitionID: NativeTabBarViewModel.appSettingsTransitionID,
                    transitionNamespace: nil,
                    appSettingsPresenter: nil
                )
            }
    }
}
