import Foundation
import PromiseKit
import Shared

final class MagicItemCustomizationViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?
    /// The entity's `supported_features`, read from its state so the behavior pickers can tell
    /// whether a climate, cover, camera, media player, or siren actually turns on and off — the
    /// frontend's `canToggleState`. `nil` until read, when it can't be, and for every other domain,
    /// which the domain alone decides.
    @Published var supportedFeatures: Int?

    private let itemProvider = Current.magicItemProvider()

    init(item: MagicItem) {
        self.item = item
    }

    /// Reads `supported_features` for the domains whose toggle depends on it. Other domains skip
    /// the round trip; a failed read leaves the domain-level answer, the way the frontend falls
    /// back without a state object.
    @MainActor
    func loadSupportedFeatures() async {
        guard item.hasMoreInfoDialog,
              let domain = item.domain,
              domain.toggleRequiredFeatures != nil,
              let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            return
        }
        let attributes = await ControlEntityProvider(domains: []).attributes(server: server, entityId: item.id)
        supportedFeatures = (attributes?["supported_features"] as? NSNumber)?.intValue
    }

    @MainActor
    func loadMagicInfo() {
        itemProvider.loadInformation { [weak self] _ in
            guard let self else { return }
            loadInfo()
        }
    }

    @MainActor
    private func loadInfo() {
        info = itemProvider.getInfo(for: item)
    }
}
