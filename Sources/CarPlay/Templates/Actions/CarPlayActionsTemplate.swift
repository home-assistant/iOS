import CarPlay
import Foundation
import RealmSwift
import Shared

final class CarPlayActionsTemplate: CarPlayTemplateProvider {
    private var actions: Results<Action>?
    private let viewModel: CarPlayActionsViewModel

    private let paginatedList = CarPlayPaginatedListTemplate(
        title: L10n.CarPlay.Navigation.Tab.quickAccess,
        items: [],
        paginationStyle: .inline
    )
    var template: CPListTemplate

    weak var interfaceController: CPInterfaceController?

    private lazy var introduceActionsListItem: CPListItem = {
        let item = CPListItem(
            text: L10n.CarPlay.Action.Intro.Item.title,
            detailText: L10n.CarPlay.Action.Intro.Item.body,
            image: MaterialDesignIcons.homeLightningBoltIcon
                .carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.viewModel.sendIntroNotification()
            self?.displayActionResultIcon(on: item, success: true)
            completion()
        }
        return item
    }()

    init(viewModel: CarPlayActionsViewModel) {
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
        viewModel.update()
    }

    func updateList(for actions: Results<Action>) {
        guard !actions.isEmpty else {
            presentIntroductionItem()
            return
        }
        paginatedList.updateItems(items: listItems(actions: actions))
    }

    private func presentIntroductionItem() {
        template.updateSections([.init(items: [introduceActionsListItem])])
    }

    private func listItems(actions: Results<Action>) -> [CPListItem] {
        let items: [CPListItem] = actions.map { action in
            let materialDesignIcon = MaterialDesignIcons(named: action.IconName)
                .carPlayIcon()
            let item = CPListItem(
                text: action.Text,
                detailText: nil,
                image: materialDesignIcon
            )
            item.handler = { [weak self] _, _ in
                self?.viewModel.handleAction(action: action) { success in
                    self?.displayActionResultIcon(on: item, success: success)
                }
            }
            return item
        }

        return items
    }

    // Present a checkmark or cross depending on success or failure
    // After 2 seconds the original icon is restored
    private func displayActionResultIcon(on item: CPListItem, success: Bool) {
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
