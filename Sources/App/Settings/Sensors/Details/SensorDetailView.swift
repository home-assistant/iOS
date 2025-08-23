import Shared
import SwiftUI

struct SensorDetailView: View {
    @StateObject var viewModel: SensorDetailViewModel

    init(sensor: WebhookSensor) {
        self._viewModel = .init(wrappedValue: SensorDetailViewModel(sensor: sensor))
    }

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: MaterialDesignIcons(serversideValueNamed: viewModel.sensor.Icon.orEmpty, fallback: .motionIcon),
                title: viewModel.sensor.Name.orEmpty
            )
            Section {
                Toggle(L10n.SettingsSensors.Detail.enabled, isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { newValue in viewModel.setEnabled(newValue) }
                ))
                if viewModel.isEnabled, let state = viewModel.stateDescription {
                    makeInfoRow(firstText: L10n.SettingsSensors.Detail.state, secondText: state)
                }
                if let deviceClass = viewModel.deviceClass {
                    makeInfoRow(firstText: L10n.SettingsSensors.Detail.deviceClass, secondText: deviceClass)
                }
                if let icon = viewModel.icon {
                    makeInfoRow(firstText: L10n.SettingsSensors.Detail.icon, secondText: icon)
                }
            }

            if !viewModel.settingsViews.isEmpty {
                Section(
                    header: Text(L10n.SettingsSensors.Settings.header),
                    footer: Text(L10n.SettingsSensors.Settings.footer)
                ) {
                    ForEach(0 ..< viewModel.settingsViews.count, id: \.self) { index in
                        viewModel.settingsViews[index]
                    }
                }
            }

            if !viewModel.attributes.isEmpty {
                Section(header: Text(L10n.SettingsSensors.Detail.attributes)) {
                    ForEach(viewModel.attributes, id: \.key) { attribute in
                        SensorDetailLabelRowView(attribute: attribute.key, value: attribute.value)
                    }
                }
            }
        }
        .removeListsPaddingWithAppleLikeHeader()
    }

    private func makeInfoRow(firstText: String, secondText: String) -> some View {
        HStack {
            Text(firstText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(secondText)
                .foregroundColor(.secondary)
        }
    }

    static func settingsSection(from settings: [WebhookSensorSetting]) -> [AnyView] {
        settings.map { setting -> AnyView in
            switch setting.type {
            case let .switch(getter, setter):
                return AnyView(
                    Toggle(isOn: Binding(
                        get: { getter() },
                        set: { newValue in setter(newValue) }
                    )) {
                        Text(setting.title)
                    }
                )
            case let .stepper(getter, setter, minimum, maximum, step, displayValueFor):
                if UIDevice.current.userInterfaceIdiom == .mac {
                    return AnyView(
                        SensorDetailsDecimalStepper(
                            title: setting.title,
                            value: Binding(
                                get: { getter() },
                                set: { newValue in
                                    var value = newValue
                                    if value < minimum { value = minimum }
                                    if value > maximum { value = maximum }
                                    let updated = (value / step).rounded(.down) * step
                                    if abs(updated - value) > 0.05 {
                                        value = updated
                                    }
                                    setter(value)
                                }
                            ),
                            minimum: minimum,
                            maximum: maximum,
                            step: step,
                            displayValueFor: displayValueFor
                        )
                    )
                } else {
                    return AnyView(
                        Stepper(
                            value: Binding(
                                get: { getter() },
                                set: { newValue in setter(newValue) }
                            ),
                            in: minimum ... maximum,
                            step: step
                        ) {
                            if let displayValueFor {
                                Text("\(setting.title): \(String(describing: displayValueFor(getter())))")
                            } else {
                                Text(setting.title)
                            }
                        }
                    )
                }
            }
        }
    }
}
