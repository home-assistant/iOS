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

    init(viewModel: CarPlayActionsViewModel) {
        self.viewModel = viewModel
        self.template = CPListTemplate(title: L10n.CarPlay.Navigation.Tab.actions, sections: [])
        template.tabTitle = L10n.CarPlay.Navigation.Tab.actions
        template.tabImage = MaterialDesignIcons.lightningBoltIcon.carPlayIcon()
        template.tabSystemItem = .more

        self.viewModel.templateProvider = self
        template.emptyViewSubtitleVariants = [L10n.SettingsDetails.Actions.title]
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
        template.updateSections([section(actions: actions)])
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
                    if success {
                        item.setImage(MaterialDesignIcons.checkIcon.carPlayIcon(color: Constants.tintColor))
                    } else {
                        item.setImage(MaterialDesignIcons.closeIcon.carPlayIcon(color: .red))
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        item.setImage(materialDesignIcon)
                    }
                }
            }
            return item
        }

        return CPListSection(items: items)
    }
}
