import CarPlay
import Foundation
import RealmSwift
import Shared

@available(iOS 15.0, *)
final class CarPlayActionsTemplate: CarPlayTemplateProvider {
    private var actionsToken: NotificationToken?
    private var actions: Results<Action>?

    var template: CPTemplate

    weak var interfaceController: CPInterfaceController?

    init() {
        self.template = CPListTemplate(title: L10n.Carplay.Navigation.Tab.actions, sections: [])
        self.template.tabTitle = L10n.Carplay.Navigation.Tab.actions
        self.template.tabImage = MaterialDesignIcons.lightningBoltIcon.carPlayIcon(color: nil)
        self.template.tabSystemItem = .more
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            actionsToken?.invalidate()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
    }

    func update() {
        let actions = Current.realm().objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")
        updateList(for: actions)
    }

    func updateList(for actions: Results<Action>) {
        actionsToken?.invalidate()
        actionsToken = actions.observe { [weak self] _ in
            self?.updateActions(actions: actions)
        }

        (template as? CPListTemplate)?.updateSections([section(actions: actions)])
        (template as? CPListTemplate)?.emptyViewTitleVariants = [L10n.SettingsDetails.Actions.title]
    }

    private func updateActions(actions: Results<Action>) {
        (template as? CPListTemplate)?.updateSections([
            section(actions: actions),
        ])
    }

    private func section(actions: Results<Action>) -> CPListSection {
        let items: [CPListItem] = actions.map { action in
            let materialDesignIcon = MaterialDesignIcons(named: action.IconName)
                .image(ofSize: CPListItem.maximumImageSize, color: UIColor(hex: action.IconColor))
            let item = CPListItem(
                text: action.Name,
                detailText: action.Text,
                image: materialDesignIcon
            )
            item.handler = { _, completion in
                guard let server = Current.servers.server(for: action) else {
                    completion()
                    return
                }
                Current.api(for: server).HandleAction(actionID: action.ID, source: .CarPlay).pipe { result in
                    switch result {
                    case .fulfilled:
                        break
                    case let .rejected(error):
                        Current.Log.info(error)
                    }
                    completion()
                }
            }
            return item
        }

        return CPListSection(items: items)
    }
}
