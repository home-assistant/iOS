#if os(iOS)
import SFSafeSymbols
import Shared
import SwiftUI

/// The settings gear at the trailing end of the More tab's bar: Home Assistant Settings for admins, and App Settings.
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
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        if let transitionNamespace {
            settingsItem.matchedTransitionSource(id: appSettingsTransitionID, in: transitionNamespace)
        } else {
            settingsItem
        }
    }

    private var settingsItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let settings = viewModel.settingsItem {
                    Button {
                        viewModel.open(settings)
                    } label: {
                        Label(L10n.TabBar.More.homeAssistantSettings, systemSymbol: .gearshape)
                    }
                }
                Button {
                    if let appSettingsPresenter {
                        viewModel.showAppSettings(using: appSettingsPresenter, zoomingFrom: appSettingsTransitionID)
                    }
                } label: {
                    Label(L10n.TabBar.More.appSettings, systemSymbol: .iphone)
                }
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
#endif
