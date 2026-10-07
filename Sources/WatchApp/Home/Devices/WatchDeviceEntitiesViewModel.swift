import Foundation
import Shared

final class WatchDeviceEntitiesViewModel: ObservableObject {
    /// `nil` until the first load finishes (spinner); empty afterwards means the device has no
    /// watch-compatible entities left.
    @Published private(set) var sections: WatchEntitySections?

    let deviceId: String
    let serverId: String

    /// Serial queue for the build — same synchronous database work (and same reasoning) as the area
    /// screen's load.
    private static let loadQueue = DispatchQueue(label: "watch-device-entities", qos: .userInitiated)
    private var isLoading = false

    init(deviceId: String, serverId: String) {
        self.deviceId = deviceId
        self.serverId = serverId
    }

    func load() {
        // Kept across `onAppear`s so returning from a controls screen doesn't rebuild the list.
        guard sections == nil, !isLoading else { return }
        isLoading = true
        let deviceId = deviceId
        let serverId = serverId
        Self.loadQueue.async { [weak self] in
            // Every entity of the device, not just the ones in the area the user came from: an
            // entity can override its device's area, and this screen is about the device.
            WatchEntitySections.make(
                serverId: serverId,
                isIncluded: { _, device in device?.deviceId == deviceId }
            ) { sections in
                DispatchQueue.main.async { [weak self] in
                    self?.sections = sections
                    self?.isLoading = false
                }
            }
        }
    }
}
