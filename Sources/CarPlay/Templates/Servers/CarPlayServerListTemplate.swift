import CarPlay
import Foundation
import HAKit
import Shared

final class CarPlayServersListTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayServerListViewModel
    private weak var tabsSelectionTemplate: CPListTemplate?
    private weak var layoutSelectionTemplate: CPListTemplate?
    private weak var serverSelectionTemplate: CPListTemplate?

    var template: CPListTemplate
    weak var sceneDelegate: CarPlaySceneDelegate?
    weak var interfaceController: CPInterfaceController? {
        didSet {
            viewModel.interfaceController = interfaceController
        }
    }

    init(viewModel: CarPlayServerListViewModel) {
        self.viewModel = viewModel
        self.template = CPListTemplate(title: L10n.CarPlay.Navigation.Tab.settings, sections: [])
        template.tabTitle = L10n.CarPlay.Labels.Tab.settings
        template.tabImage = MaterialDesignIcons.cogIcon.carPlayIcon()

        viewModel.templateProvider = self
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == tabsSelectionTemplate {
            viewModel.commitTabSelection()
            tabsSelectionTemplate = nil
        }

        if template == layoutSelectionTemplate {
            viewModel.commitLayoutSelection()
            layoutSelectionTemplate = nil
        }

        if template == serverSelectionTemplate {
            viewModel.commitServerSelection()
            serverSelectionTemplate = nil
        }

        if template == self.template {
            viewModel.removeServerObserver()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            viewModel.addServerObserver()
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        /* no-op */
    }

    @objc func update() {
        template.updateSections([
            CPListSection(items: [
                mainServerItem,
                layoutItem,
                tabsItem,
                troubleshootingItem,
            ]),
        ])
    }

    func showNoServerAlert() {
        guard interfaceController?.presentedTemplate == nil else {
            return
        }

        let alertTemplate = CarPlayNoServerAlert()
        alertTemplate.interfaceController = interfaceController
        alertTemplate.present()
    }

    private var mainServerItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Labels.Settings.MainServer.title,
            detailText: CarPlayPreferredServer.current?.info.name
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentServerSelection()
            completion()
        }
        return item
    }

    private var layoutItem: CPListItem {
        let item = CPListItem(
            text: L10n.Carplay.Tab.QuickAccess.layout,
            detailText: viewModel.quickAccessLayout.name
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentLayoutSelection()
            completion()
        }
        return item
    }

    private var tabsItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Config.Tabs.title,
            detailText: viewModel.tabsSummary
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentTabsSelection()
            completion()
        }
        return item
    }

    private var troubleshootingItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Labels.Settings.Troubleshooting.title,
            detailText: nil
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentTroubleshooting()
            completion()
        }
        return item
    }

    private func serverItem(server: Server, template: CPListTemplate) -> CPListItem {
        let serverItem = CPListItem(
            text: server.info.name,
            detailText: nil,
            image: viewModel.isServerActive(server) ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        serverItem.handler = { [weak self, weak template] _, completion in
            guard let self, let template else {
                completion()
                return
            }

            viewModel.setServer(server)
            template.updateSections([serverSelectionSection(template: template)])
            completion()
        }
        serverItem.accessoryType = .none
        return serverItem
    }

    private func presentServerSelection() {
        viewModel.beginServerSelection()
        let selectionTemplate = CPListTemplate(title: L10n.CarPlay.Labels.Settings.MainServer.title, sections: [])
        serverSelectionTemplate = selectionTemplate
        selectionTemplate.updateSections([serverSelectionSection(template: selectionTemplate)])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }

    private func serverSelectionSection(template: CPListTemplate) -> CPListSection {
        let servers = Current.servers.all
            .filter { $0.info.connection.activeURL() != nil }
            .map { serverItem(server: $0, template: template) }

        guard !servers.isEmpty else {
            return CPListSection(items: [
                CPListItem(text: L10n.CarPlay.Labels.noServersAvailable, detailText: nil),
            ])
        }

        return CPListSection(items: servers, header: L10n.CarPlay.Labels.selectServer, sectionIndexTitle: nil)
    }

    private func presentLayoutSelection() {
        viewModel.beginLayoutSelection()
        let selectionTemplate = CPListTemplate(title: L10n.Carplay.Tab.QuickAccess.layout, sections: [])
        layoutSelectionTemplate = selectionTemplate
        selectionTemplate.updateSections([layoutSelectionSection(template: selectionTemplate)])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }

    private func layoutSelectionSection(template: CPListTemplate) -> CPListSection {
        CPListSection(items: CarPlayQuickAccessLayout.allCases.map { layoutItem(layout: $0, template: template) })
    }

    private func layoutItem(layout: CarPlayQuickAccessLayout, template: CPListTemplate) -> CPListItem {
        let item = CPListItem(
            text: layout.name,
            detailText: nil,
            image: viewModel.isLayoutActive(layout) ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self, weak template] _, completion in
            guard let self, let template else {
                completion()
                return
            }

            viewModel.setLayout(layout)
            template.updateSections([layoutSelectionSection(template: template)])
            completion()
        }
        return item
    }

    private func presentTabsSelection() {
        viewModel.beginTabSelection()
        let selectionTemplate = CPListTemplate(title: L10n.CarPlay.Config.Tabs.title, sections: [])
        tabsSelectionTemplate = selectionTemplate
        selectionTemplate.updateSections([tabsSelectionSection(template: selectionTemplate)])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }

    private func tabsSelectionSection(template: CPListTemplate) -> CPListSection {
        CPListSection(items: CarPlayTab.allCases.map { tabItem(tab: $0, template: template) })
    }

    private func tabItem(tab: CarPlayTab, template: CPListTemplate) -> CPListItem {
        let item = CPListItem(
            text: tab.name,
            detailText: nil,
            image: viewModel.isTabActive(tab) ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self, weak template] _, completion in
            guard let self, let template else {
                completion()
                return
            }

            if tab != .settings {
                viewModel.setTab(tab, active: !viewModel.isTabActive(tab))
                template.updateSections([tabsSelectionSection(template: template)])
            }
            completion()
        }
        return item
    }

    private func presentTroubleshooting() {
        let troubleshootingTemplate = CPListTemplate(
            title: L10n.CarPlay.Labels.Settings.Troubleshooting.title,
            sections: [
                CPListSection(items: [
                    assistAudioItem,
                    forceCloseItem,
                ]),
            ]
        )
        interfaceController?.pushTemplate(troubleshootingTemplate, animated: true, completion: nil)
    }

    private var assistAudioItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Labels.Settings.Troubleshooting.AssistAudio.title,
            detailText: viewModel.ttsPlaybackStrategy.title
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentAssistAudioSelection()
            completion()
        }
        return item
    }

    private func presentAssistAudioSelection() {
        let selectionTemplate = CPListTemplate(
            title: L10n.CarPlay.Labels.Settings.Troubleshooting.AssistAudio.title,
            sections: [
                CPListSection(items: CarPlayAssistTTSPlaybackStrategy.allCases.map {
                    ttsPlaybackStrategyItem(strategy: $0)
                }),
            ]
        )
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }

    private func ttsPlaybackStrategyItem(strategy: CarPlayAssistTTSPlaybackStrategy) -> CPListItem {
        let item = CPListItem(
            text: strategy.title,
            detailText: nil,
            image: viewModel.ttsPlaybackStrategy == strategy ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self] _, completion in
            self?.viewModel.setTTSPlaybackStrategy(strategy)
            self?.interfaceController?.popTemplate(animated: true, completion: nil)
            completion()
        }
        return item
    }

    private var forceCloseItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Labels.Settings.Troubleshooting.ForceClose.title,
            detailText: nil
        )
        item.handler = { _, _ in
            fatalError("Intentional crash, triggered from CarPlay Troubleshooting option to restart App.")
        }
        return item
    }
}
