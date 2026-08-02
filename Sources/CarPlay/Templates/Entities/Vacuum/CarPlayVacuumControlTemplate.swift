import CarPlay
import Foundation
import HAKit
import Shared

/// Pushed control screen for a vacuum entity: start/pause, stop, return to dock, locate and fan
/// speed, each shown only when the entity supports the capability. Vacuums have no single tap
/// action, so their rows navigate here instead of executing.
final class CarPlayVacuumControlTemplate: CarPlayTemplateProvider {
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private let viewModel: CarPlayVacuumControlViewModel

    // Rows are cached and mutated in place: `updateSections` resets rotary-knob focus, so it only
    // runs when the entity's capabilities (or the state-driven primary command) change, not on
    // every value refresh.
    private var statusItem: CPListItem?
    private var fanSpeedItem: CPListItem?
    private var capabilitySignature: [String] = []

    init(viewModel: CarPlayVacuumControlViewModel) {
        self.viewModel = viewModel
        self.template = CPListTemplate(title: viewModel.entityName, sections: [])
        template.emptyViewSubtitleVariants = [L10n.CarPlay.State.Loading.title]
        viewModel.templateProvider = self
        rebuildSections()
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            /* no-op */
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if self.template == template {
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        viewModel.updateStates(serverId: serverId, entities: entities)
    }

    func update() {
        refreshDisplayedValues()
    }

    func refreshDisplayedValues() {
        guard currentCapabilitySignature() == capabilitySignature else {
            rebuildSections()
            return
        }
        applyDisplayedValues()
    }

    private func currentCapabilitySignature() -> [String] {
        let capabilities = viewModel.capabilities
        return [
            String(capabilities.supportsStart),
            String(capabilities.supportsPause),
            String(capabilities.supportsStop),
            String(capabilities.supportsReturnHome),
            String(capabilities.supportsLocate),
            String(capabilities.supportsFanSpeed),
            capabilities.fanSpeedList.joined(separator: ","),
            // The primary command row (start vs pause) follows the cleaning state.
            String(viewModel.isCleaning),
        ]
    }

    private func rebuildSections() {
        let capabilities = viewModel.capabilities
        capabilitySignature = currentCapabilitySignature()
        var sections: [CPListSection] = []

        statusItem = nil
        fanSpeedItem = nil

        let status = CPListItem(text: nil, detailText: nil)
        statusItem = status

        var commandItems: [CPListItem] = [status]
        if viewModel.isCleaning, capabilities.supportsPause {
            commandItems.append(commandItem(
                text: L10n.Vacuum.Control.pause,
                icon: .pauseIcon
            ) { [weak self] in
                self?.viewModel.pause()
            })
        } else if capabilities.supportsStart {
            commandItems.append(commandItem(
                text: L10n.Vacuum.Control.start,
                icon: .playIcon
            ) { [weak self] in
                self?.viewModel.start()
            })
        }
        if capabilities.supportsStop {
            commandItems.append(commandItem(
                text: L10n.Vacuum.Control.stop,
                icon: .stopIcon
            ) { [weak self] in
                self?.viewModel.stop()
            })
        }
        if capabilities.supportsReturnHome {
            commandItems.append(commandItem(
                text: L10n.Vacuum.Control.returnToBase,
                icon: .homeImportOutlineIcon
            ) { [weak self] in
                self?.viewModel.returnToBase()
            })
        }
        if capabilities.supportsLocate {
            commandItems.append(commandItem(
                text: L10n.Vacuum.Control.locate,
                icon: .mapMarkerIcon
            ) { [weak self] in
                self?.viewModel.locate()
            })
        }
        sections.append(CPListSection(items: commandItems))

        if capabilities.supportsFanSpeed {
            let item = CPListItem(text: L10n.Vacuum.Control.FanSpeed.title, detailText: nil)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.presentFanSpeedSelection()
                completion()
            }
            fanSpeedItem = item
            sections.append(CPListSection(items: [item]))
        }

        applyDisplayedValues()
        template.updateSections(sections)
    }

    private func applyDisplayedValues() {
        let capabilities = viewModel.capabilities

        if let statusItem {
            statusItem.setText(viewModel.stateText)
            statusItem.setDetailText(
                capabilities.batteryLevel.map { L10n.Vacuum.Control.battery("\(Int($0))%") }
            )
            statusItem.setImage(MaterialDesignIcons.robotVacuumIcon.carPlayIcon())
        }
        if let fanSpeedItem {
            fanSpeedItem.setDetailText(capabilities.fanSpeed.map(ClimateControlState.displayName(forMode:)))
            fanSpeedItem.setImage(MaterialDesignIcons.fanIcon.carPlayIcon())
        }
    }

    private func commandItem(
        text: String,
        icon: MaterialDesignIcons,
        action: @escaping () -> Void
    ) -> CPListItem {
        let item = CPListItem(text: text, detailText: nil, image: icon.carPlayIcon())
        item.handler = { _, completion in
            action()
            completion()
        }
        return item
    }

    /// Pushes a single-choice fan speed list; the current value carries a check icon, and
    /// selecting pops straight back to the control screen.
    private func presentFanSpeedSelection() {
        let items = viewModel.capabilities.fanSpeedList.map { speed in
            let isSelected = speed == viewModel.capabilities.fanSpeed
            let item = CPListItem(
                text: ClimateControlState.displayName(forMode: speed),
                detailText: nil,
                image: isSelected ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
            )
            item.handler = { [weak self] _, completion in
                self?.viewModel.setFanSpeed(speed)
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }
        let selectionTemplate = CPListTemplate(
            title: L10n.Vacuum.Control.FanSpeed.title,
            sections: [CPListSection(items: items)]
        )
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }
}
