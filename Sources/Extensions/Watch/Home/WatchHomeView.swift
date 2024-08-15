import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: WatchHomeViewModel
    @State private var showAssist = false

    let reloadAction: () -> Void

    init(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info], reloadAction: @escaping () -> Void) {
        self._viewModel = .init(wrappedValue: .init(watchConfig: watchConfig, magicItemsInfo: magicItemsInfo))
        self.reloadAction = reloadAction
    }

    var body: some View {
        content
            .fullScreenCover(isPresented: $showAssist, content: {
                WatchAssistView.build()
            })
            .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
                showAssist = true
            }
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
            ForEach(viewModel.watchConfig.items, id: \.id) { item in
                WatchHomeRowView(
                    item: item,
                    itemInfo: viewModel.info(for: item)
                ) { item, completion in
                    viewModel.executeMagicItem(item) { success in
                        completion(success)
                    }
                }
            }
            reloadButton
        }
        .navigationTitle("")
        .modify {
            if #available(watchOS 10, *), viewModel.watchConfig.showAssist {
                $0.toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            showAssist = true
                        }, label: {
                            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                                ofSize: .init(width: 24, height: 24),
                                color: Asset.Colors.haPrimary.color
                            ))
                        })
                    }
                }
            } else {
                $0
            }
        }
    }

    private var reloadButton: some View {
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
                ], reloadAction: {}
            )
        }
    } else {
        return Text("Check preview watch version")
    }
}

extension WatchConfig {
    static var fixture: WatchConfig = {
        var config = WatchConfig()
        config.showAssist = true
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
