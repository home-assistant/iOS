import CarPlay
import Foundation
import HAKit
import Shared

/// Pushed control screen for a climate entity: the options the frontend's more-info dialog offers
/// (target temperature, HVAC mode, fan/swing/preset modes, humidity), each shown only when the
/// entity supports the capability.
final class CarPlayClimateControlTemplate: CarPlayTemplateProvider {
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private let viewModel: CarPlayClimateControlViewModel

    // Rows are cached and mutated in place: `updateSections` resets rotary-knob focus, so it only
    // runs when the entity's capabilities change (e.g. the first real snapshot replacing a
    // placeholder), not on every value refresh.
    private var temperatureValueItem: CPListItem?
    private var temperatureLowValueItem: CPListItem?
    private var temperatureHighValueItem: CPListItem?
    private var humidityValueItem: CPListItem?
    private var hvacModeItem: CPListItem?
    private var fanModeItem: CPListItem?
    private var swingModeItem: CPListItem?
    private var swingHorizontalModeItem: CPListItem?
    private var presetModeItem: CPListItem?
    private var capabilitySignature: [String] = []

    init(viewModel: CarPlayClimateControlViewModel) {
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
        let control = viewModel.control
        return [
            String(control.supportsTargetTemperature),
            String(control.supportsTargetTemperatureRange),
            String(control.supportsTargetHumidity),
            control.hvacModes.joined(separator: ","),
            control.fanModes.joined(separator: ","),
            control.swingModes.joined(separator: ","),
            control.swingHorizontalModes.joined(separator: ","),
            control.presetModes.joined(separator: ","),
        ]
    }

    private func rebuildSections() {
        let control = viewModel.control
        capabilitySignature = currentCapabilitySignature()
        var sections: [CPListSection] = []

        temperatureValueItem = nil
        temperatureLowValueItem = nil
        temperatureHighValueItem = nil
        humidityValueItem = nil
        hvacModeItem = nil
        fanModeItem = nil
        swingModeItem = nil
        swingHorizontalModeItem = nil
        presetModeItem = nil

        if control.supportsTargetTemperature {
            let valueItem = CPListItem(text: nil, detailText: nil)
            temperatureValueItem = valueItem
            sections.append(CPListSection(
                items: [
                    valueItem,
                    stepItem(text: L10n.Climate.Control.Temperature.increase, icon: .plusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperature(by: 1)
                    },
                    stepItem(text: L10n.Climate.Control.Temperature.decrease, icon: .minusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperature(by: -1)
                    },
                ],
                header: L10n.Climate.Control.Temperature.title,
                sectionIndexTitle: nil
            ))
        }

        if control.supportsTargetTemperatureRange {
            let lowValueItem = CPListItem(text: nil, detailText: nil)
            temperatureLowValueItem = lowValueItem
            sections.append(CPListSection(
                items: [
                    lowValueItem,
                    stepItem(text: L10n.Climate.Control.Temperature.increase, icon: .plusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperatureLow(by: 1)
                    },
                    stepItem(text: L10n.Climate.Control.Temperature.decrease, icon: .minusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperatureLow(by: -1)
                    },
                ],
                header: L10n.Climate.Control.TemperatureLow.title,
                sectionIndexTitle: nil
            ))

            let highValueItem = CPListItem(text: nil, detailText: nil)
            temperatureHighValueItem = highValueItem
            sections.append(CPListSection(
                items: [
                    highValueItem,
                    stepItem(text: L10n.Climate.Control.Temperature.increase, icon: .plusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperatureHigh(by: 1)
                    },
                    stepItem(text: L10n.Climate.Control.Temperature.decrease, icon: .minusIcon) { [weak self] in
                        self?.viewModel.adjustTargetTemperatureHigh(by: -1)
                    },
                ],
                header: L10n.Climate.Control.TemperatureHigh.title,
                sectionIndexTitle: nil
            ))
        }

        var modeItems: [CPListItem] = []
        if control.supportsHvacModes {
            let item = selectionItem(text: L10n.Climate.Control.Mode.title) { [weak self] in
                self?.presentHvacModeSelection()
            }
            hvacModeItem = item
            modeItems.append(item)
        }
        if control.supportsFanMode {
            let item = selectionItem(text: L10n.Climate.Control.FanMode.title) { [weak self] in
                self?.presentModeSelection(
                    title: L10n.Climate.Control.FanMode.title,
                    options: self?.viewModel.control.fanModes ?? [],
                    selectedOption: { $0.control.fanMode },
                    onSelect: { $0.setFanMode($1) }
                )
            }
            fanModeItem = item
            modeItems.append(item)
        }
        if control.supportsSwingMode {
            let item = selectionItem(text: L10n.Climate.Control.SwingMode.title) { [weak self] in
                self?.presentModeSelection(
                    title: L10n.Climate.Control.SwingMode.title,
                    options: self?.viewModel.control.swingModes ?? [],
                    selectedOption: { $0.control.swingMode },
                    onSelect: { $0.setSwingMode($1) }
                )
            }
            swingModeItem = item
            modeItems.append(item)
        }
        if control.supportsSwingHorizontalMode {
            let item = selectionItem(text: L10n.Climate.Control.SwingHorizontalMode.title) { [weak self] in
                self?.presentModeSelection(
                    title: L10n.Climate.Control.SwingHorizontalMode.title,
                    options: self?.viewModel.control.swingHorizontalModes ?? [],
                    selectedOption: { $0.control.swingHorizontalMode },
                    onSelect: { $0.setSwingHorizontalMode($1) }
                )
            }
            swingHorizontalModeItem = item
            modeItems.append(item)
        }
        if control.supportsPresetMode {
            let item = selectionItem(text: L10n.Climate.Control.PresetMode.title) { [weak self] in
                self?.presentModeSelection(
                    title: L10n.Climate.Control.PresetMode.title,
                    options: self?.viewModel.control.presetModes ?? [],
                    selectedOption: { $0.control.presetMode },
                    onSelect: { $0.setPresetMode($1) }
                )
            }
            presetModeItem = item
            modeItems.append(item)
        }
        if !modeItems.isEmpty {
            sections.append(CPListSection(
                items: modeItems,
                header: L10n.Climate.Control.Modes.title,
                sectionIndexTitle: nil
            ))
        }

        if control.supportsTargetHumidity {
            let valueItem = CPListItem(text: nil, detailText: nil)
            humidityValueItem = valueItem
            sections.append(CPListSection(
                items: [
                    valueItem,
                    stepItem(text: L10n.Climate.Control.Humidity.increase, icon: .plusIcon) { [weak self] in
                        self?.viewModel.adjustTargetHumidity(by: 1)
                    },
                    stepItem(text: L10n.Climate.Control.Humidity.decrease, icon: .minusIcon) { [weak self] in
                        self?.viewModel.adjustTargetHumidity(by: -1)
                    },
                ],
                header: L10n.Climate.Control.Humidity.title,
                sectionIndexTitle: nil
            ))
        }

        applyDisplayedValues()
        template.updateSections(sections)
    }

    private func applyDisplayedValues() {
        let control = viewModel.control

        if let temperatureValueItem {
            let target = control.targetTemperature.map(ClimateControlState.formatTemperature) ?? "—"
            temperatureValueItem.setText(L10n.Climate.Control.targetValue(target))
            temperatureValueItem.setDetailText(
                control.currentTemperature
                    .map { L10n.Climate.Control.currentValue(ClimateControlState.formatTemperature($0)) }
            )
            temperatureValueItem.setImage(MaterialDesignIcons.thermometerIcon.carPlayIcon())
        }
        if let temperatureLowValueItem {
            let target = control.targetTemperatureLow.map(ClimateControlState.formatTemperature) ?? "—"
            temperatureLowValueItem.setText(L10n.Climate.Control.targetValue(target))
            temperatureLowValueItem.setImage(MaterialDesignIcons.fireIcon.carPlayIcon())
        }
        if let temperatureHighValueItem {
            let target = control.targetTemperatureHigh.map(ClimateControlState.formatTemperature) ?? "—"
            temperatureHighValueItem.setText(L10n.Climate.Control.targetValue(target))
            temperatureHighValueItem.setImage(MaterialDesignIcons.snowflakeIcon.carPlayIcon())
        }
        if let humidityValueItem {
            let target = control.targetHumidity.map(ClimateControlState.formatHumidity) ?? "—"
            humidityValueItem.setText(L10n.Climate.Control.targetValue(target))
            humidityValueItem.setDetailText(
                control.currentHumidity
                    .map { L10n.Climate.Control.currentValue(ClimateControlState.formatHumidity($0)) }
            )
            humidityValueItem.setImage(MaterialDesignIcons.waterPercentIcon.carPlayIcon())
        }
        if let hvacModeItem {
            hvacModeItem.setDetailText(ClimateHvacMode.localizedTitle(forMode: control.hvacMode))
            let icon = ClimateHvacMode(rawValue: control.hvacMode)?.icon ?? .thermostatIcon
            hvacModeItem.setImage(icon.carPlayIcon())
        }
        if let fanModeItem {
            fanModeItem.setDetailText(control.fanMode.map(ClimateControlState.displayName(forMode:)))
            fanModeItem.setImage(MaterialDesignIcons.fanIcon.carPlayIcon())
        }
        if let swingModeItem {
            swingModeItem.setDetailText(control.swingMode.map(ClimateControlState.displayName(forMode:)))
            swingModeItem.setImage(MaterialDesignIcons.arrowOscillatingIcon.carPlayIcon())
        }
        if let swingHorizontalModeItem {
            swingHorizontalModeItem
                .setDetailText(control.swingHorizontalMode.map(ClimateControlState.displayName(forMode:)))
            swingHorizontalModeItem.setImage(MaterialDesignIcons.arrowLeftRightIcon.carPlayIcon())
        }
        if let presetModeItem {
            presetModeItem.setDetailText(control.presetMode.map(ClimateControlState.displayName(forMode:)))
            presetModeItem.setImage(MaterialDesignIcons.tuneIcon.carPlayIcon())
        }
    }

    private func stepItem(
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

    private func selectionItem(text: String, action: @escaping () -> Void) -> CPListItem {
        let item = CPListItem(text: text, detailText: nil)
        item.accessoryType = .disclosureIndicator
        item.handler = { _, completion in
            action()
            completion()
        }
        return item
    }

    private func presentHvacModeSelection() {
        let items = viewModel.control.hvacModes.map { mode in
            let isSelected = mode == viewModel.control.hvacMode
            let icon = ClimateHvacMode(rawValue: mode)?.icon
            let item = CPListItem(
                text: ClimateHvacMode.localizedTitle(forMode: mode),
                detailText: nil,
                image: isSelected ? MaterialDesignIcons.checkIcon.carPlayIcon() : icon?.carPlayIcon()
            )
            item.handler = { [weak self] _, completion in
                self?.viewModel.setHvacMode(mode)
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }
        pushSelectionTemplate(title: L10n.Climate.Control.Mode.title, items: items)
    }

    /// Pushes a single-choice list for a free-form mode attribute (fan/swing/preset); the current
    /// value carries a check icon, and selecting pops straight back to the control screen.
    private func presentModeSelection(
        title: String,
        options: [String],
        selectedOption: @escaping (CarPlayClimateControlViewModel) -> String?,
        onSelect: @escaping (CarPlayClimateControlViewModel, String) -> Void
    ) {
        let items = options.map { option in
            let isSelected = option == selectedOption(viewModel)
            let item = CPListItem(
                text: ClimateControlState.displayName(forMode: option),
                detailText: nil,
                image: isSelected ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
            )
            item.handler = { [weak self] _, completion in
                guard let self else {
                    completion()
                    return
                }
                onSelect(viewModel, option)
                interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }
        pushSelectionTemplate(title: title, items: items)
    }

    private func pushSelectionTemplate(title: String, items: [CPListItem]) {
        let selectionTemplate = CPListTemplate(title: title, sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }
}
