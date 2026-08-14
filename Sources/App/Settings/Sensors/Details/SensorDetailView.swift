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
                    SensorDetailLabelRowView(attribute: L10n.SettingsSensors.Detail.state, value: state)
                }
                if let deviceClass = viewModel.deviceClass {
                    SensorDetailLabelRowView(attribute: L10n.SettingsSensors.Detail.deviceClass, value: deviceClass)
                }
                if let icon = viewModel.icon {
                    SensorDetailLabelRowView(attribute: L10n.SettingsSensors.Detail.icon, value: icon)
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

            if let footer = viewModel.sensor.detailFooter {
                Section(footer: Text(footer)) {}
            }
        }
    }

    static func settingsSection(from settings: [WebhookSensorSetting]) -> [AnyView] {
        settings.flatMap { setting -> [AnyView] in
            if case let .credentials(fields) = setting.type {
                return credentialRows(fields: fields, footer: setting.subtitle)
            }
            let row = makeRow(for: setting)
            guard let subtitle = setting.subtitle else { return [row] }
            return [AnyView(
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    row
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            )]
        }
    }

    /// A `.credentials` setting renders as one row per field plus a trailing Save row,
    /// all sharing a single `CredentialsDraft` so Save commits every field at once.
    private static func credentialRows(fields: [WebhookSensorSetting.CredentialField], footer: String?) -> [AnyView] {
        let draft = CredentialsDraft(fields: fields)
        var rows = fields.indices.map { index in
            AnyView(SensorDetailCredentialFieldRow(draft: draft, index: index))
        }
        rows.append(AnyView(SensorDetailCredentialSaveRow(draft: draft, footer: footer)))
        return rows
    }

    private static func makeRow(for setting: WebhookSensorSetting) -> AnyView {
        {
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
            case let .slider(getter, setter, minimum, maximum, step, displayValueFor):
                return AnyView(
                    SensorDetailSliderRow(
                        title: setting.title,
                        minimum: minimum,
                        maximum: maximum,
                        step: step,
                        displayValueFor: displayValueFor,
                        getter: getter,
                        setter: setter
                    )
                )
            case let .options(getter, setter, values, displayValueFor):
                return AnyView(
                    SensorDetailOptionsRow(
                        title: setting.title,
                        values: values,
                        displayValueFor: displayValueFor,
                        getter: getter,
                        setter: setter
                    )
                )
            case let .numericField(getter, setter, minimum, maximum):
                return AnyView(
                    SensorDetailNumericFieldRow(
                        title: setting.title,
                        minimum: minimum,
                        maximum: maximum,
                        getter: getter,
                        setter: setter
                    )
                )
            case .credentials:
                return AnyView(EmptyView())
            }
        }()
    }
}
