import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: WatchHomeViewModel
    @Binding var showAssist: Bool
    let reloadAction: () -> Void

    init(
        watchConfig: WatchConfig,
        magicItemsInfo: [MagicItem.Info],
        showAssist: Binding<Bool>,
        reloadAction: @escaping () -> Void
    ) {
        self._viewModel = .init(wrappedValue: .init(watchConfig: watchConfig, magicItemsInfo: magicItemsInfo))
        self._showAssist = showAssist
        self.reloadAction = reloadAction
    }

    var body: some View {
        content
            .onChange(of: scenePhase) { newScenePhase in
                switch newScenePhase {
                case .active:
                    viewModel.fetchNetworkInfo(completion: nil)
                default:
                    break
                }
            }
    }

    private var content: some View {
        List {
            if #unavailable(watchOS 10),
               viewModel.watchConfig.assist.showAssist,
               !viewModel.watchConfig.assist.serverId.isEmpty,
               !viewModel.watchConfig.assist.pipelineId.isEmpty {
                assistButton
            }
            ForEach(viewModel.watchConfig.items, id: \.serverUniqueId) { item in
                WatchMagicViewRow(
                    item: item,
                    itemInfo: viewModel.info(for: item)
                )
            }
            reloadButton
        }
        .navigationTitle("")
    }

    private var assistButton: some View {
        Button {
            showAssist = true
        } label: {
            HStack {
                Image(uiImage: MaterialDesignIcons.messageTextOutlineIcon.image(
                    ofSize: .init(width: 24, height: 24),
                    color: Asset.Colors.haPrimary.color
                ))
                Text("Assist")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var reloadButton: some View {
        // When watchOS 10 is available, reload is on toolbar
        if #unavailable(watchOS 10.0) {
            Button {
                reloadAction()
            } label: {
                Label(L10n.reloadLabel, systemImage: "arrow.circlepath")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.footnote)
            }
            .listRowBackground(Color.clear)
        }
    }
}

#if DEBUG
#Preview {
    MaterialDesignIcons.register()
    if #available(watchOS 9.0, *) {
        return NavigationStack {
            WatchHomeView(
                watchConfig: WatchConfig.fixture,
                magicItemsInfo: [
                    .init(id: "1", name: "This is a script", iconName: "mdi:access-point-check"),
                    .init(id: "2", name: "This is an action", iconName: "fire_alert"),
                ], showAssist: .constant(false), reloadAction: {}
            )
        }
    } else {
        return Text("Check preview watch version")
    }
}

extension WatchConfig {
    static var fixture: WatchConfig = {
        var config = WatchConfig()
        config.assist = .init(showAssist: true)
        config.items = [
            .init(id: "1", serverId: "1", type: .script),
            .init(
                id: "2", serverId: "1", type: .action,
                customization: .init(
                    textColor: "#ff00ff",
                    backgroundColor: "#ff00ff"
                )
            ),
        ]
        return config
    }()
}
#endif
