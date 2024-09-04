import Communicator
import Foundation
import NetworkExtension
import PromiseKit
import Shared

final class WatchHomeViewModel: ObservableObject {
    @Published private(set) var watchConfig: WatchConfig
    @Published private(set) var magicItemsInfo: [MagicItem.Info]

    init(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        self.watchConfig = watchConfig
        self.magicItemsInfo = magicItemsInfo
    }

    func info(for magicItem: MagicItem) -> MagicItem.Info {
        magicItemsInfo.first(where: { $0.id == magicItem.id }) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: ""
        )
    }

    func fetchNetworkInfo(completion: (() -> Void)? = nil) {
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
        }
    }
}
