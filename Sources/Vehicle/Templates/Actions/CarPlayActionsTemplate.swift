import CarPlay
import Foundation
import RealmSwift
import Shared

@available(iOS 15.0, *)
final class CarPlayActionsTemplate: CarPlayTemplateProvider {
    private var actions: Results<Action>?
    private let viewModel: CarPlayActionsViewModel

    var template: CPListTemplate

    weak var interfaceController: CPInterfaceController?

    private lazy var introduceActionsListItem: CPListItem = {
        let item = CPListItem(
            text: L10n.CarPlay.Action.Intro.Item.title,
            detailText: L10n.CarPlay.Action.Intro.Item.body,
            image: MaterialDesignIcons.homeLightningBoltIcon
                .carPlayIcon(carUserInterfaceStyle: interfaceController?.carTraitCollection.userInterfaceStyle)
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
        self.template = CPListTemplate(title: L10n.CarPlay.Navigation.Tab.actions, sections: [])
        template.tabTitle = L10n.CarPlay.Navigation.Tab.actions
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
        template.updateSections([section(actions: actions)])
    }

    private func presentIntroductionItem() {
        template.updateSections([.init(items: [introduceActionsListItem])])
    }

    private func section(actions: Results<Action>) -> CPListSection {
        let items: [CPListItem] = actions.map { action in
            let materialDesignIcon = MaterialDesignIcons(named: action.IconName)
                .carPlayIcon(carUserInterfaceStyle: interfaceController?.carTraitCollection.userInterfaceStyle)
            let item = CPListItem(
                text: action.Name,
                detailText: action.Text,
                image: materialDesignIcon
            )
            item.handler = { [weak self] _, _ in
                self?.viewModel.handleAction(action: action) { success in
                    self?.displayActionResultIcon(on: item, success: success)
                }
            }
            return item
        }

        return CPListSection(items: items)
    }

    // Present a checkmark or cross depending on success or failure
    // After 2 seconds the original icon is restored
    private func displayActionResultIcon(on item: CPListItem, success: Bool) {
        let itemOriginalIcon = item.image
        if success {
            item.setImage(MaterialDesignIcons.checkIcon.carPlayIcon(color: Constants.tintColor))
        } else {
            item.setImage(MaterialDesignIcons.closeIcon.carPlayIcon(color: .red))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            item.setImage(itemOriginalIcon)
        }
    }
}
