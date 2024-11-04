import CarPlay
import Foundation
import PromiseKit
import RealmSwift
import Shared

final class CarPlayQuickAccessTemplate: CarPlayTemplateProvider {
    private var actions: Results<Action>?
    private let viewModel: CarPlayQuickAccessViewModel

    private let paginatedList = CarPlayPaginatedListTemplate(
        title: L10n.CarPlay.Navigation.Tab.quickAccess,
        items: [],
        paginationStyle: .inline
    )
    var template: CPListTemplate

    private var magicItemProvider: MagicItemProviderProtocol = Current.magicItemProvider()
    weak var interfaceController: CPInterfaceController?

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
        template.emptyViewSubtitleVariants = [L10n.SettingsDetails.Actions.title]
        presentIntroductionItem()
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            viewModel.invalidateActionsToken()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    func update() {
        magicItemProvider.loadInformation { [weak self] in
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
        let items: [CPListItem] = items.map { magicItem in
            let info = magicItemProvider.getInfo(for: magicItem)
            let icon = magicItem.icon(info: info).carPlayIcon(color: .init(hex: info.customization?.iconColor))
            let item = CPListItem(
                text: info.name,
                detailText: nil,
                image: icon
            )
            item.handler = { [weak self] _, _ in
                if info.customization?.requiresConfirmation ?? false {
                    self?.showConfirmationForRunningMagicItem(item: magicItem, info: info) {
                        self?.executeMagicItem(magicItem, item: item)
                    }
                } else {
                    self?.executeMagicItem(magicItem, item: item)
                }
            }
            return item
        }

        return items
    }

    private func executeMagicItem(_ magicItem: MagicItem, item: CPListItem) {
        guard let server = Current.servers.all.first(where: { server in
            server.identifier.rawValue == magicItem.serverId
        }) else {
            Current.Log.error("Failed to get server for magic item id: \(magicItem.id)")
            displayItemResultIcon(on: item, success: false)
            return
        }
        Current.api(for: server).executeMagicItem(item: magicItem) { success in
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
