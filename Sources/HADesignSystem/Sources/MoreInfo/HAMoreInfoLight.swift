#if !os(watchOS)
import HAIconic
import SwiftUI

/// A light's more-info dialog: the brightness slider, the colour wheel or the colour-temperature
/// slider (one at a time, picked from the row of toggles under them), or a plain on/off switch for
/// a light that only switches, and the effect picker. The SwiftUI counterpart of the frontend's
/// `more-info-light`.
public struct HAMoreInfoLight: View {
    private enum MainControl {
        case brightness
        case color
        case colorTemperature
    }

    private let state: String
    private let lastChanged: Date
    private let now: Date
    private let color: Color
    private let brightness: Binding<Double>?
    private let hue: Binding<Double>?
    private let saturation: Binding<Double>?
    private let colorTemperature: Binding<Double>?
    private let kelvinRange: ClosedRange<Double>
    private let onSetWhite: (() -> Void)?
    private let isUnavailable: Bool
    private let selects: [HAMoreInfoSelect]
    @Binding private var isOn: Bool
    @State private var mainControl: MainControl?

    /// - Parameters:
    ///   - state: The header: the brightness as a percentage while on, else the state.
    ///   - color: The light's colour, lifted for contrast when it is nearly white, as
    ///     `ha-state-control-light-brightness` does.
    ///   - brightness: 1–100, for a light that dims. Without it the dialog shows a switch.
    ///   - hue: 0–360 with `saturation` 0–1, for a colour light.
    ///   - colorTemperature: In kelvin within `kelvinRange`, for a tunable white light.
    ///   - onSetWhite: Adds the set-white button, for a light with a `white` colour mode.
    ///   - selects: The effect picker, when the light has effects.
    public init(
        state: String,
        lastChanged: Date,
        now: Date,
        isOn: Binding<Bool>,
        color: Color,
        brightness: Binding<Double>? = nil,
        hue: Binding<Double>? = nil,
        saturation: Binding<Double>? = nil,
        colorTemperature: Binding<Double>? = nil,
        kelvinRange: ClosedRange<Double> = HAColorTemperature.defaultMinKelvin ... HAColorTemperature.defaultMaxKelvin,
        onSetWhite: (() -> Void)? = nil,
        isUnavailable: Bool = false,
        selects: [HAMoreInfoSelect] = []
    ) {
        self.state = state
        self.lastChanged = lastChanged
        self.now = now
        _isOn = isOn
        self.color = color
        self.brightness = brightness
        self.hue = hue
        self.saturation = saturation
        self.colorTemperature = colorTemperature
        self.kelvinRange = kelvinRange
        self.onSetWhite = onSetWhite
        self.isUnavailable = isUnavailable
        self.selects = selects
    }

    private var strings: HADesignSystemEnvironment.Strings { HADesignSystemEnvironment.current.strings }
    private var supportsColor: Bool { hue != nil && saturation != nil }

    private var selectedControl: MainControl {
        mainControl ?? .brightness
    }

    private var colorTemperatureGradient: Gradient {
        let gradient = HAColorTemperature.gradient(minKelvin: kelvinRange.lowerBound, maxKelvin: kelvinRange.upperBound)
        return Gradient(stops: gradient.stops.map { .init(color: $0.color, location: 1 - $0.location) })
    }

    private func toggle(_ control: MainControl) -> Binding<Bool> {
        Binding(get: { selectedControl == control }, set: { _ in mainControl = control })
    }

    public var body: some View {
        HAMoreInfoLayout {
            HAMoreInfoStateHeader(state: state, lastChanged: lastChanged, now: now)
        } controls: {
            if brightness == nil {
                HAStateControlToggle(
                    isOn: $isOn,
                    onColor: color,
                    iconOn: .lightbulbOnIcon,
                    iconOff: .lightbulbOffIcon,
                    isDisabled: isUnavailable
                )
            }
            if brightness != nil || supportsColor || colorTemperature != nil {
                switch selectedControl {
                case .brightness:
                    if let brightness {
                        HAStateControlSlider(
                            value: brightness,
                            scale: HASliderScale(min: 1, max: 100),
                            color: color,
                            showsHandle: isOn,
                            isDisabled: isUnavailable,
                            label: strings.lightBrightness
                        )
                    }
                case .color:
                    if let hue, let saturation {
                        HAHSColorPicker(
                            hue: hue,
                            saturation: saturation,
                            diameter: DesignSystem.StateControl.dialDiameter,
                            isDisabled: isUnavailable
                        )
                    }
                case .colorTemperature:
                    if let colorTemperature {
                        HAStateControlSlider(
                            value: colorTemperature,
                            scale: HASliderScale(
                                min: kelvinRange.lowerBound,
                                max: kelvinRange.upperBound,
                                inverted: true
                            ),
                            mode: .cursor,
                            track: .gradient(colorTemperatureGradient),
                            color: color,
                            showsHandle: false,
                            isDisabled: isUnavailable,
                            label: strings.lightColorTemperature
                        )
                    }
                }
                HAIconButtonGroup {
                    if brightness != nil {
                        HAIconButtonToggle(
                            icon: .powerIcon,
                            label: strings.toggle,
                            isSelected: Binding(get: { false }, set: { _ in isOn.toggle() })
                        )
                    }
                    if supportsColor || colorTemperature != nil {
                        if brightness != nil {
                            HAIconButtonToggle(
                                icon: .brightness6Icon,
                                label: strings.lightBrightness,
                                isSelected: toggle(.brightness)
                            )
                        }
                        if supportsColor {
                            HAIconButtonToggle(
                                swatch: AngularGradient(
                                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                    center: .center
                                ),
                                label: strings.lightColor,
                                isSelected: toggle(.color)
                            )
                        }
                        if colorTemperature != nil {
                            HAIconButtonToggle(
                                swatch: LinearGradient(
                                    gradient: HAColorTemperature.gradient(
                                        minKelvin: kelvinRange.lowerBound,
                                        maxKelvin: kelvinRange.upperBound
                                    ),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                label: strings.lightColorTemperature,
                                isSelected: toggle(.colorTemperature)
                            )
                        }
                    }
                    if let onSetWhite {
                        HAIconButtonToggle(
                            icon: .fileWordBoxIcon,
                            label: strings.lightSetWhite,
                            isSelected: Binding(get: { false }, set: { _ in onSetWhite() })
                        )
                    }
                }
                .disabled(isUnavailable)
            }
        } footer: {
            HAMoreInfoControlSelectContainer(selects: selects)
        }
    }
}

#Preview {
    ScrollView {
        HAMoreInfoLight(
            state: "100%",
            lastChanged: Date(timeIntervalSinceNow: -3480),
            now: Date(),
            isOn: .constant(true),
            color: Color(.sRGB, red: 0.1, green: 0.3, blue: 1),
            brightness: .constant(100),
            hue: .constant(225),
            saturation: .constant(0.9),
            colorTemperature: .constant(4000),
            selects: [
                HAMoreInfoSelect(
                    id: "effect",
                    label: "Effect",
                    icon: .creationIcon,
                    options: [.init(id: "rainbow", label: "Rainbow")],
                    selection: .constant(nil)
                ),
            ]
        )
        .padding(DesignSystem.Spaces.three)
    }
}

extension HAMoreInfoLight: FrontendComponent {
    public static var frontendComponentName: String { "more-info-light" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
