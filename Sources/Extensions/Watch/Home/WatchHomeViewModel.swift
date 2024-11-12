import Communicator
import Foundation
import NetworkExtension
import PromiseKit
import Shared

final class WatchHomeViewModel: ObservableObject {
    func fetchNetworkInfo(completion: (() -> Void)? = nil) {
        NEHotspotNetwork.fetchCurrent { hotspotNetwork in
            WatchUserDefaults.shared.set(hotspotNetwork?.ssid, key: .watchSSID)
            completion?()
        }
    }
}
