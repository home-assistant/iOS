import CarPlay
import Foundation
import Shared

@available(iOS 16.0, *)
final class CarPlayAddItemFlow {
    private enum Step {
        case servers
        case category(Server)
        case areas(Server)
        case domains(Server)
        case entities(server: Server, title: String, entities: [HAAppEntity])
    }

    private weak var interfaceController: CPInterfaceController?
    private let viewModel: CarPlayAddItemViewModel
    private let onFinish: () -> Void

    private let template = CPListTemplate(title: L10n.CarPlay.QuickAccess.AddItem.title, sections: [])
    private var steps: [Step] = []

    init(
        interfaceController: CPInterfaceController?,
        viewModel: CarPlayAddItemViewModel = CarPlayAddItemViewModel(),
        onFinish: @escaping () -> Void
    ) {
        self.interfaceController = interfaceController
        self.viewModel = viewModel
        self.onFinish = onFinish
    }

    func start() {
        let servers = viewModel.servers
        guard !servers.isEmpty else {
            Current.Log.error("Attempted to start CarPlay add item flow without any server")
            onFinish()
            return
        }
        steps = [servers.count > 1 ? .servers : .category(servers[0])]
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
        render()
    }

    private func go(to step: Step) {
        steps.append(step)
        render()
    }

    private func goBack() {
        if steps.count > 1 {
            steps.removeLast()
            render()
        } else {
            interfaceController?.popTemplate(animated: true, completion: nil)
            onFinish()
        }
    }

    private func render() {
        guard let step = steps.last else { return }
        var sections: [CPListSection] = []
        // A "Back" row, rather than a nav-bar button, avoids sitting next to the pushed template's
        // system back button (which exits the whole flow).
        if steps.count > 1 {
            sections.append(CPListSection(items: [backRow()]))
        }
        sections.append(contentSection(for: step))
        template.updateSections(sections)
    }

    private func contentSection(for step: Step) -> CPListSection {
        switch step {
        case .servers:
            return serversSection()
        case let .category(server):
            return categorySection(server: server)
        case let .areas(server):
            return areasSection(server: server)
        case let .domains(server):
            return domainsSection(server: server)
        case let .entities(server, title, entities):
            return entitiesSection(server: server, title: title, entities: entities)
        }
    }

    private func serversSection() -> CPListSection {
        let rows = viewModel.servers.map { server in
            navigationRow(title: server.info.name, image: nil) { [weak self] in
                self?.go(to: .category(server))
            }
        }
        return section(header: L10n.CarPlay.Labels.selectServer, rows: rows)
    }

    private func categorySection(server: Server) -> CPListSection {
        let areas = navigationRow(
            title: L10n.CarPlay.Navigation.Tab.areas,
            image: MaterialDesignIcons.sofaIcon.carPlayIcon()
        ) { [weak self] in self?.go(to: .areas(server)) }
        let control = navigationRow(
            title: L10n.CarPlay.Navigation.Tab.domains,
            image: MaterialDesignIcons.devicesIcon.carPlayIcon()
        ) { [weak self] in self?.go(to: .domains(server)) }
        return section(header: server.info.name, rows: [areas, control])
    }

    private func areasSection(server: Server) -> CPListSection {
        let serverId = server.identifier.rawValue
        let rows = viewModel.areas(serverId: serverId).map { area -> CPListItem in
            let icon = viewModel.icon(for: area).carPlayIcon()
            return navigationRow(title: area.name, image: icon) { [weak self] in
                guard let self else { return }
                go(to: .entities(
                    server: server,
                    title: area.name,
                    entities: viewModel.entities(serverId: serverId, area: area)
                ))
            }
        }
        return section(
            header: L10n.CarPlay.Navigation.Tab.areas,
            rows: rows,
            emptyMessage: L10n.CarPlay.Labels.emptyDomainList
        )
    }

    private func domainsSection(server: Server) -> CPListSection {
        let serverId = server.identifier.rawValue
        let rows = viewModel.domains(serverId: serverId).map { domain -> CPListItem in
            let icon = viewModel.icon(for: domain).carPlayIcon()
            return navigationRow(title: domain.localizedDescription, image: icon) { [weak self] in
                guard let self else { return }
                go(to: .entities(
                    server: server,
                    title: domain.localizedDescription,
                    entities: viewModel.entities(serverId: serverId, domain: domain)
                ))
            }
        }
        return section(
            header: L10n.CarPlay.Navigation.Tab.domains,
            rows: rows,
            emptyMessage: L10n.CarPlay.Labels.emptyDomainList
        )
    }

    private func entitiesSection(server: Server, title: String, entities: [HAAppEntity]) -> CPListSection {
        let rows = entities.map { entity -> CPListItem in
            let icon = viewModel.icon(for: entity).carPlayIcon()
            return navigationRow(title: entity.name, image: icon) { [weak self] in
                self?.presentConfirmation(server: server, entity: entity)
            }
        }
        return section(header: title, rows: rows, emptyMessage: L10n.CarPlay.NoEntities.title)
    }

    private func presentConfirmation(server: Server, entity: HAAppEntity) {
        let requireAction = CPAlertAction(
            title: L10n.CarPlay.QuickAccess.AddItem.Confirmation.require,
            style: .default
        ) { [weak self] _ in
            self?.commit(server: server, entity: entity, requiresConfirmation: true)
        }
        let directAction = CPAlertAction(
            title: L10n.CarPlay.QuickAccess.AddItem.Confirmation.noConfirmation,
            style: .default
        ) { [weak self] _ in
            self?.commit(server: server, entity: entity, requiresConfirmation: false)
        }
        let cancelAction = CPAlertAction(
            title: L10n.Alerts.Confirm.cancel,
            style: .cancel
        ) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }

        let actionSheet = CPActionSheetTemplate(
            title: entity.name,
            message: L10n.CarPlay.QuickAccess.AddItem.Confirmation.footer,
            actions: [requireAction, directAction, cancelAction]
        )
        interfaceController?.presentTemplate(actionSheet, animated: true, completion: nil)
    }

    private func commit(server: Server, entity: HAAppEntity, requiresConfirmation: Bool) {
        viewModel.addEntityToQuickAccess(
            entityId: entity.entityId,
            serverId: server.identifier.rawValue,
            requiresConfirmation: requiresConfirmation
        )
        interfaceController?.dismissTemplate(animated: true, completion: nil)
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        onFinish()
    }

    private func section(header: String, rows: [CPListItem], emptyMessage: String? = nil) -> CPListSection {
        guard !rows.isEmpty else {
            return CPListSection(items: [infoRow(title: emptyMessage ?? "")], header: header, sectionIndexTitle: nil)
        }
        // Reserve one slot for the Back row so the template never exceeds CarPlay's item cap.
        let maxItems = max(1, Int(CPListTemplate.maximumItemCount) - 1)
        if rows.count > maxItems {
            Current.Log.error("CarPlay add item list of \(rows.count) exceeds \(maxItems); truncating")
        }
        return CPListSection(items: Array(rows.prefix(maxItems)), header: header, sectionIndexTitle: nil)
    }

    private func navigationRow(title: String, image: UIImage?, handler: @escaping () -> Void) -> CPListItem {
        let item = CPListItem(text: title, detailText: nil, image: image)
        item.accessoryType = .disclosureIndicator
        item.handler = { _, completion in
            handler()
            completion()
        }
        return item
    }

    private func infoRow(title: String) -> CPListItem {
        CPListItem(text: title, detailText: nil)
    }

    private func backRow() -> CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.QuickAccess.AddItem.back,
            detailText: nil,
            image: MaterialDesignIcons.arrowLeftIcon.carPlayIcon()
        )
        item.handler = { [weak self] _, completion in
            self?.goBack()
            completion()
        }
        return item
    }
}
