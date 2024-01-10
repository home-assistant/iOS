import CarPlay
import Foundation
import RealmSwift
import Shared

@available(iOS 15.0, *)
final class CarPlayActionsTemplate: CarPlayTemplateProvider {
    private var listTemplate: CPListTemplate?
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
        template = list(for: actions)
        template.tabTitle = L10n.Carplay.Navigation.Tab.actions
        template.tabImage = MaterialDesignIcons.lightningBoltIcon.image(
            ofSize: .init(width: 64, height: 64),
            color: nil
        )
        template.tabSystemItem = .more
    }

    func list(for actions: Results<Action>) -> CPTemplate {
        actionsToken = actions.observe { [weak self] _ in
            self?.updateActions(actions: actions)
        }

        if actions.isEmpty {
            return noActionsView
        } else {
            listTemplate = CPListTemplate(
                title: L10n.SettingsDetails.Actions.title, sections: [
                    section(actions: actions),
                ]
            )

            guard let listTemplate else { return noActionsView }
            return listTemplate
        }
    }

    private func updateActions(actions: Results<Action>) {
        listTemplate?.updateSections([
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
