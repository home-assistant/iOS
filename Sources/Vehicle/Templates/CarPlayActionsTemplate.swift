import CarPlay
import Foundation
import RealmSwift
import Shared

@available(iOS 15.0, *)
final class CarPlayActionsTemplate: CarPlayTemplateProvider {
    private var actionsToken: NotificationToken?
    private let actions: Results<Action>

    private var noActionsView: CPInformationTemplate = {
        CPInformationTemplate(
            title: L10n.About.Logo.title,
            layout: .leading,
            items: [
                .init(title: L10n.CarPlay.NoActions.title, detail: nil),
            ],
            actions: []
        )
    }()

    var template: CPTemplate

    weak var interfaceController: CPInterfaceController?

    init(actions: Results<Action>) {
        self.actions = actions
        self.template = CPTemplate()
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
        updateList(for: actions)
        template.tabTitle = L10n.Carplay.Navigation.Tab.actions
        template.tabImage = MaterialDesignIcons.lightningBoltIcon.image(
            ofSize: .init(width: 64, height: 64),
            color: nil
        )
        template.tabSystemItem = .more
    }

    func updateList(for actions: Results<Action>) {
        actionsToken?.invalidate()
        actionsToken = actions.observe { [weak self] _ in
            self?.updateActions(actions: actions)
        }

        if let listTemplate = template as? CPListTemplate {
            listTemplate.updateSections([section(actions: actions)])
        } else {
            template = CPListTemplate(
                title: L10n.SettingsDetails.Actions.title, sections: [
                    section(actions: actions),
                ]
            )
        }

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
