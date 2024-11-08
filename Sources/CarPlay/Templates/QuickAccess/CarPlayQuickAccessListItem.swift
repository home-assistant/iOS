import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayQuickAccessListItem: CarPlayListItemProvider {
    var item: MagicItem
    var info: MagicItem.Info
    var template: CPListItem
    weak var interfaceController: CPInterfaceController?

    private var statesSubscriptions: HACancellable?

    private var lastState: String?

    init(item: MagicItem, info: MagicItem.Info) {
        self.template = CPListItem(text: nil, detailText: nil)
        self.item = item
        self.info = info
        update()
        subscribe()
    }

    deinit {
        statesSubscriptions?.cancel()
    }

    private func subscribe() {
        statesSubscriptions?.cancel()
        guard let server = Current.servers.all.first(where: { item.serverId == $0.identifier.rawValue }) else { return }
        statesSubscriptions = Current.api(for: server).connection.caches.states.subscribe { [weak self] _, states in
            guard let self else { return }
            let itemState = states.all.first(where: { $0.entityId == self.item.id })?.state
            lastState = itemState
            updateState()
        }
    }

    private func update() {
        template.setText(info.name)
        let icon = item.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
        template.setImage(icon)
    }

    private func updateState() {
        template.setDetailText(lastState?.capitalized ?? "Unknown")
    }
}
