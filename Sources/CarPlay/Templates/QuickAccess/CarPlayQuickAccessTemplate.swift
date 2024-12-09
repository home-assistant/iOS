import CarPlay
import Foundation
import HAKit
import PromiseKit
import RealmSwift
import Shared

@available(iOS 16.0, *)
final class CarPlayQuickAccessTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayQuickAccessViewModel

    private let paginatedList = CarPlayPaginatedListTemplate(
        title: L10n.CarPlay.Navigation.Tab.quickAccess,
        items: [],
        paginationStyle: .inline
    )
    var template: CPListTemplate

    private var magicItemProvider: MagicItemProviderProtocol = Current.magicItemProvider()
    weak var interfaceController: CPInterfaceController?
    private var entityProviders: [CarPlayEntityListItem] = []
    private var entitiesPerServer: [String: HACachedStates] = [:]

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    private lazy var introduceQuickAccessListItem: CPListItem = {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.Intro.Item.title,
            detailText: L10n.CarPlay.Action.Intro.Item.body,
            image: MaterialDesignIcons.homeLightningBoltIcon
                .carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.viewModel.sendIntroNotification()
            self?.displayItemResultIcon(on: item, success: true)
            completion()
        }
        return item
    }()

    init(viewModel: CarPlayQuickAccessViewModel) {
        self.viewModel = viewModel

        self.template = paginatedList.template
        template.tabTitle = L10n.CarPlay.Navigation.Tab.quickAccess
        template.tabImage = MaterialDesignIcons.lightningBoltIcon.carPlayIcon()
        template.tabSystemItem = .more

        self.viewModel.templateProvider = self
        presentIntroductionItem()
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            /* no-op */
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        entitiesPerServer[serverId] = entities
        entityProviders.forEach { item in
            guard serverId == item.serverId else { return }
            guard let entity = entities.all.filter({ $0.entityId == item.entity.entityId }).first else { return }
            item.update(serverId: serverId, entity: entity)
        }
    }

    func update() {
        magicItemProvider.loadInformation { [weak self] _ in
            self?.viewModel.update()
        }
    }

    func updateList(for items: [MagicItem]) {
        guard !items.isEmpty else {
            presentIntroductionItem()
            return
        }
        paginatedList.updateItems(items: listItems(items: items))
    }

    private func presentIntroductionItem() {
        template.updateSections([.init(items: [introduceQuickAccessListItem])])
    }

    private func listItems(items: [MagicItem]) -> [CPListItem] {
        entityProviders = []
        let items: [CPListItem?] = items.compactMap { magicItem in
            let info = magicItemProvider.getInfo(for: magicItem) ?? .init(
                id: magicItem.id,
                name: magicItem.id,
                iconName: "",
                customization: nil
            )
            switch magicItem.type {
            case .entity:
                guard let placeholderItem = entitiesPerServer[magicItem.serverId]?.all
                    .first(where: { $0.entityId == magicItem.id }) ?? placeholderEntity(id: magicItem.id) else {
                    Current.Log.error("Failed to create placeholder entity for magic item id: \(magicItem.id)")
                    return .init(text: "", detailText: "")
                }
                let entityProvider = CarPlayEntityListItem(serverId: magicItem.serverId, entity: placeholderItem)
                let listItem = entityProvider.template
                listItem.handler = { [weak self] _, _ in
                    self?.itemTap(magicItem: magicItem, info: info, item: listItem)
                }
                entityProviders.append(entityProvider)
                return listItem
            default:

                let icon = magicItem.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
                let item = CPListItem(
                    text: info.name,
                    detailText: nil,
                    image: icon
                )
                item.handler = { [weak self] _, _ in
                    self?.itemTap(magicItem: magicItem, info: info, item: item)
                }
                return item
            }
        }

        return items.compactMap({ $0 })
    }

    private func placeholderEntity(id: String) -> HAEntity? {
        try? HAEntity(
            entityId: id,
            state: "",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func itemTap(
        magicItem: MagicItem,
        info: MagicItem.Info,
        item: CPListItem
    ) {
        if info.customization?.requiresConfirmation ?? false {
            showConfirmationForRunningMagicItem(item: magicItem, info: info) { [weak self] in
                self?.executeMagicItem(magicItem, item: item)
            }
        } else {
            executeMagicItem(magicItem, item: item)
        }
    }

    private func executeMagicItem(_ magicItem: MagicItem, item: CPListItem) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }), let api = Current.api(for: server) else {
            Current.Log.error("Failed to get server for magic item id: \(magicItem.id)")
            displayItemResultIcon(on: item, success: false)
            return
        }
        api.executeMagicItem(item: magicItem) { success in
            self.displayItemResultIcon(on: item, success: success)
        }
    }

    private func showConfirmationForRunningMagicItem(
        item: MagicItem,
        info: MagicItem.Info,
        completion: @escaping () -> Void
    ) {
        let alert = CPAlertTemplate(titleVariants: [
            L10n.Watch.Home.Run.Confirmation.title(info.name),
        ], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .default, handler: { [weak self] _ in
                completion()
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }

    // Present a checkmark or cross depending on success or failure
    // After 2 seconds the original icon is restored
    private func displayItemResultIcon(on item: CPListItem, success: Bool) {
        let itemOriginalIcon = item.image
        if success {
            item.setImage(MaterialDesignIcons.checkIcon.carPlayIcon(color: AppConstants.tintColor))
        } else {
            item.setImage(MaterialDesignIcons.closeIcon.carPlayIcon(color: .red))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            item.setImage(itemOriginalIcon)
        }
    }
}
