#if !os(watchOS)
import SwiftUI

/// The variants of the more-info dialogs and the pieces they are built from, kept apart from the
/// rest of the library because each dialog demonstrates several entity configurations, the same
/// ones the frontend's `gallery/src/pages/more-info/` pages render.
extension DesignSystemComponent {
    var moreInfoVariants: [DesignSystemComponentVariant] {
        switch self {
        case .controlSelectMenu:
            [
                .init("With value") {
                    HAControlSelectMenu(Self.sampleModeSelect(selection: "heat")).frame(width: 140)
                },
                .init("With arrow") {
                    HAControlSelectMenu(
                        label: "Fan mode",
                        icon: .fanIcon,
                        options: [.init(id: "low", label: "Low"), .init(id: "high", label: "High")],
                        selection: .constant("low"),
                        showsArrow: true
                    )
                    .frame(width: 160)
                },
                .init("No value") {
                    HAControlSelectMenu(Self.sampleModeSelect(selection: nil)).frame(width: 140)
                },
                .init("Disabled") {
                    HAControlSelectMenu(
                        label: "Mode",
                        icon: .thermostatIcon,
                        options: [],
                        selection: .constant(nil),
                        isDisabled: true
                    )
                    .frame(width: 140)
                },
            ]
        case .outlinedIconButton:
            [
                .init("Default") { HAOutlinedIconButton(icon: .plusIcon, label: "Increase") {} },
                .init("Tinted outline") {
                    HAOutlinedIconButton(
                        icon: .minusIcon,
                        label: "Decrease",
                        outlineColor: FrontendColors.stateClimateHeatColor.color
                    ) {}
                },
                .init("Disabled") {
                    HAOutlinedIconButton(icon: .powerIcon, label: "Power", isDisabled: true) {}
                },
            ]
        case .moreInfoDialog:
            [
                .init("Light in the dialog chrome") {
                    HAMoreInfoDialog(
                        title: "Ceiling light",
                        breadcrumb: ["Living room", "Hue bridge"],
                        onClose: {}
                    ) {
                        MaterialDesignIconsImage(icon: .chartBoxOutlineIcon, size: 24)
                        MaterialDesignIconsImage(icon: .cogOutlineIcon, size: 24)
                        MaterialDesignIconsImage(icon: .dotsVerticalIcon, size: 24)
                    } content: {
                        HAMoreInfoLight(
                            state: "78%",
                            lastChanged: Self.sampleDate.addingTimeInterval(-540),
                            now: Self.sampleDate,
                            isOn: .constant(true),
                            color: FrontendColors.stateLightActiveColor.color,
                            brightness: .constant(78)
                        )
                    }
                    .frame(height: 620)
                },
            ]
        case .moreInfoLayout:
            [
                .init("Header, controls and pickers") {
                    HAMoreInfoLayout {
                        HAMoreInfoStateHeader(
                            state: "On",
                            lastChanged: Self.sampleDate.addingTimeInterval(-120),
                            now: Self.sampleDate
                        )
                    } controls: {
                        HAStateControlToggle(
                            isOn: .constant(true),
                            onColor: FrontendColors.stateSwitchActiveColor.color
                        )
                    } footer: {
                        HAMoreInfoControlSelectContainer(selects: [Self.sampleModeSelect(selection: "heat")])
                    }
                },
            ]
        case .moreInfoStateHeader:
            [
                .init("State and time") {
                    HAMoreInfoStateHeader(
                        state: "On",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2040),
                        now: Self.sampleDate
                    )
                },
                .init("With an accessory") {
                    HAMoreInfoStateHeader(
                        state: "Docked",
                        lastChanged: Self.sampleDate.addingTimeInterval(-1140),
                        now: Self.sampleDate
                    ) {
                        HAMoreInfoBattery(level: 84, isCharging: true)
                    }
                },
            ]
        case .moreInfoReadings:
            [
                .init("One reading") { HAMoreInfoReadings(Self.sampleTemperatureReadings) },
                .init("Two readings") {
                    HAMoreInfoReadings(
                        Self.sampleTemperatureReadings + [.init(label: "Current humidity", value: "40 %")]
                    )
                },
            ]
        case .moreInfoControlSelectContainer:
            [
                .init("Fits") {
                    HAMoreInfoControlSelectContainer(selects: [
                        Self.sampleModeSelect(selection: "heat"),
                        Self.samplePresetSelect,
                    ])
                },
                .init("Scrolls") {
                    HAMoreInfoControlSelectContainer(selects: [
                        Self.sampleModeSelect(selection: "heat"),
                        Self.samplePresetSelect,
                        Self.sampleFanModeSelect,
                        Self.sampleSwingSelect,
                    ])
                },
            ]
        case .moreInfoBattery:
            [
                .init("Level") { HAMoreInfoBattery(level: 84) },
                .init("Charging") { HAMoreInfoBattery(level: 42, isCharging: true) },
                .init("Low") { HAMoreInfoBattery(level: 8) },
                .init("Binary sensor, no level") { HAMoreInfoBattery(level: nil) },
            ]
        case .moreInfoStateCard:
            [
                .init("With text") {
                    HAMoreInfoStateCard(
                        name: "Box",
                        icon: .rayVertexIcon,
                        lastChanged: Self.sampleDate.addingTimeInterval(-1200),
                        now: Self.sampleDate
                    ) {
                        Text("0 items")
                    }
                },
            ]
        case .moreInfoCommandBar:
            [
                .init("Commands") { HAMoreInfoCommandBar(Self.sampleVacuumCommands(isCleaning: true)) },
                .init("Some unavailable") { HAMoreInfoCommandBar(Self.sampleVacuumCommands(isCleaning: false)) },
            ]
        case .stateControlCircularSlider:
            [
                .init("Single target") {
                    HAStateControlCircularSlider(
                        value: .constant(20),
                        scale: Self.sampleClimateScale,
                        current: 18,
                        color: FrontendColors.stateClimateHeatColor.color,
                        label: "Preheating",
                        labelColor: FrontendColors.stateClimateHeatColor.color,
                        unit: "°C",
                        fractionLength: 1
                    )
                },
                .init("Dual target") {
                    HAStateControlCircularSlider(
                        low: .constant(20),
                        high: .constant(25),
                        scale: HACircularSliderScale(min: 10, max: 30, step: 1),
                        current: 18,
                        lowColor: FrontendColors.stateClimateHeatColor.color,
                        highColor: FrontendColors.stateClimateCoolColor.color,
                        label: "Heating",
                        labelColor: FrontendColors.stateClimateHeatColor.color,
                        unit: "°C"
                    )
                },
                .init("Nothing to set") {
                    HAStateControlCircularSlider(
                        state: "Fan only",
                        scale: HACircularSliderScale(min: 0, max: 1, step: 1),
                        color: FrontendColors.stateClimateFanOnlyColor.color,
                        label: "Fan",
                        labelColor: FrontendColors.stateClimateFanOnlyColor.color
                    )
                },
                .init("Unavailable") {
                    HAStateControlCircularSlider(
                        state: nil,
                        scale: Self.sampleClimateScale,
                        color: .haDisabled,
                        isDisabled: true,
                        label: "Unavailable"
                    )
                },
            ]
        case .stateControlToggle:
            [
                .init("Switch") {
                    HStack(spacing: DesignSystem.Spaces.three) {
                        HAStateControlToggle(
                            isOn: .constant(true),
                            onColor: FrontendColors.stateLightActiveColor.color,
                            iconOn: .lightbulbOnIcon,
                            iconOff: .lightbulbOffIcon
                        )
                        HAStateControlToggle(
                            isOn: .constant(false),
                            onColor: FrontendColors.stateLightActiveColor.color,
                            iconOn: .lightbulbOnIcon,
                            iconOff: .lightbulbOffIcon
                        )
                    }
                },
                .init("Assumed state") {
                    HAStateControlToggle(
                        isOn: .constant(true),
                        onColor: FrontendColors.stateSwitchActiveColor.color,
                        isAssumedState: true
                    )
                },
            ]
        case .stateControlSlider:
            [
                .init("Tinted, slats and gradient") {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        HAStateControlSlider(
                            value: .constant(78),
                            scale: HASliderScale(min: 1, max: 100),
                            color: FrontendColors.stateLightActiveColor.color
                        )
                        HAStateControlSlider(
                            value: .constant(30),
                            mode: .cursor,
                            track: .slats,
                            color: FrontendColors.stateCoverActiveColor.color,
                            showsHandle: false
                        )
                    }
                },
                .init("Colour temperature") {
                    HAStateControlSlider(
                        value: .constant(4000),
                        scale: HASliderScale(min: 2000, max: 6500, inverted: true),
                        mode: .cursor,
                        track: .gradient(Gradient(
                            stops: HAColorTemperature.gradient(minKelvin: 2000, maxKelvin: 6500)
                                .stops.map { .init(color: $0.color, location: 1 - $0.location) }
                        )),
                        color: FrontendColors.stateLightActiveColor.color,
                        showsHandle: false
                    )
                },
            ]
        case .stateControlCoverButtons:
            [
                .init("Line") {
                    HAStateControlCoverButtons(
                        open: Self.sampleCoverOpen,
                        stop: Self.sampleCoverStop,
                        close: Self.sampleCoverClose
                    )
                },
                .init("Cross, with tilt") {
                    HAStateControlCoverButtons(
                        open: Self.sampleCoverOpen,
                        stop: Self.sampleCoverStop,
                        close: Self.sampleCoverClose,
                        openTilt: Self.sampleCoverOpenTilt,
                        closeTilt: Self.sampleCoverCloseTilt
                    )
                },
                .init("Tilt only") {
                    HAStateControlCoverButtons(
                        stop: Self.sampleCoverStop,
                        openTilt: Self.sampleCoverOpenTilt,
                        closeTilt: Self.sampleCoverCloseTilt
                    )
                },
            ]
        case .stateControlVacuumStatus:
            [
                .init("Every state") {
                    LazyVGrid(columns: [GridItem(), GridItem()]) {
                        ForEach(HARobotVisualState.allCases, id: \.self) { state in
                            VStack(spacing: .zero) {
                                HAStateControlVacuumStatus(state: state, color: Self.sampleVacuumColor(state))
                                    .scaleEffect(0.7)
                                    .frame(width: 140, height: 140)
                                Text(state.rawValue).font(DesignSystem.Font.caption)
                            }
                        }
                    }
                },
            ]
        case .stateControlLawnMowerStatus:
            [
                .init("Every state") {
                    LazyVGrid(columns: [GridItem(), GridItem()]) {
                        ForEach(HARobotVisualState.allCases, id: \.self) { state in
                            VStack(spacing: .zero) {
                                HAStateControlLawnMowerStatus(
                                    state: state,
                                    color: state == .error ? FrontendColors.stateLawnMowerErrorColor.color
                                        : state == .active || state == .returning
                                        ? FrontendColors.stateLawnMowerActiveColor.color : .haDisabled
                                )
                                .scaleEffect(0.7)
                                .frame(width: 140, height: 140)
                                Text(state.rawValue).font(DesignSystem.Font.caption)
                            }
                        }
                    }
                },
            ]
        case .moreInfoClimate:
            [
                .init("Basic heater") {
                    HAMoreInfoClimate(
                        readings: Self.sampleTemperatureReadings,
                        target: .single(.constant(20)),
                        scale: Self.sampleClimateScale,
                        current: 18,
                        unit: "°C",
                        color: FrontendColors.stateClimateHeatColor.color,
                        action: "Preheating",
                        actionColor: FrontendColors.stateClimateHeatColor.color,
                        selects: [Self.sampleModeSelect(selection: "heat")]
                    )
                },
                .init("Basic air conditioning") {
                    HAMoreInfoClimate(
                        readings: Self.sampleTemperatureReadings,
                        target: .single(.constant(20), mode: .end),
                        scale: Self.sampleClimateScale,
                        current: 18,
                        unit: "°C",
                        color: FrontendColors.stateClimateCoolColor.color,
                        action: "Cooling",
                        actionColor: FrontendColors.stateClimateCoolColor.color,
                        selects: [Self.sampleModeSelect(selection: "cool")]
                    )
                },
                .init("Basic fan") {
                    HAMoreInfoClimate(
                        readings: [],
                        target: .none(state: "Fan only"),
                        scale: HACircularSliderScale(min: 0, max: 1, step: 1),
                        unit: "°C",
                        color: FrontendColors.stateClimateFanOnlyColor.color,
                        action: "Fan",
                        actionColor: FrontendColors.stateClimateFanOnlyColor.color,
                        selects: [Self.sampleModeSelect(selection: "fan_only"), Self.sampleFanModeSelect]
                    )
                },
                .init("Advanced hvac") {
                    HAMoreInfoClimate(
                        readings: Self.sampleTemperatureReadings + [.init(label: "Current humidity", value: "40 %")],
                        target: .range(low: .constant(20), high: .constant(25)),
                        scale: HACircularSliderScale(min: 10, max: 30, step: 1),
                        current: 18,
                        unit: "°C",
                        fractionLength: 0,
                        color: FrontendColors.stateClimateHeatCoolColor.color,
                        action: "Heating",
                        actionColor: FrontendColors.stateClimateHeatColor.color,
                        humidity: .init(
                            target: .constant(50),
                            current: 40,
                            color: FrontendColors.stateHumidifierOnColor.color,
                            label: "Target humidity",
                            temperatureToggleLabel: "Temperature",
                            humidityToggleLabel: "Humidity"
                        ),
                        selects: [Self.sampleModeSelect(selection: "auto"), Self.samplePresetSelect]
                    )
                },
            ]
        case .moreInfoHumidifier:
            [
                .init("Humidifying") {
                    HAMoreInfoHumidifier(
                        readings: [.init(label: "Current humidity", value: "45 %")],
                        target: .constant(60),
                        state: "On",
                        current: 45,
                        color: FrontendColors.stateHumidifierOnColor.color,
                        action: "Humidifying",
                        actionColor: FrontendColors.stateHumidifierOnColor.color,
                        selects: [Self.sampleOnOffSelect(selection: "on"), Self.sampleHumidifierModeSelect]
                    )
                },
                .init("Off") {
                    HAMoreInfoHumidifier(
                        readings: [.init(label: "Current humidity", value: "45 %")],
                        target: .constant(60),
                        state: "Off",
                        current: 45,
                        color: .haDisabled,
                        isActive: false,
                        selects: [Self.sampleOnOffSelect(selection: "off")]
                    )
                },
            ]
        case .moreInfoWaterHeater:
            [
                .init("Eco") {
                    HAMoreInfoWaterHeater(
                        readings: [.init(label: "Current temperature", value: "55 °C")],
                        target: .constant(60),
                        state: "Eco",
                        targetLabel: "Target",
                        scale: HACircularSliderScale(min: 45, max: 70, step: 1),
                        current: 55,
                        unit: "°C",
                        color: FrontendColors.stateWaterHeaterEcoColor.color,
                        selects: [Self.sampleWaterHeaterModeSelect, Self.sampleAwaySelect]
                    )
                },
                .init("Unavailable") {
                    HAMoreInfoWaterHeater(
                        readings: [],
                        target: nil,
                        state: "Unavailable",
                        targetLabel: "Target",
                        scale: HACircularSliderScale(min: 45, max: 70, step: 1),
                        unit: "°C",
                        color: .haDisabled,
                        isUnavailable: true
                    )
                },
            ]
        case .moreInfoFan:
            [
                .init("On/off only") {
                    HAMoreInfoFan(
                        state: "On",
                        lastChanged: Self.sampleDate.addingTimeInterval(-3600),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        speed: .toggle,
                        color: FrontendColors.stateFanActiveColor.color,
                        selects: [Self.sampleOscillatingSelect]
                    )
                },
                .init("Named speeds") {
                    HAMoreInfoFan(
                        state: "67%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2340),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        speed: .steps(Self.sampleFanSpeeds, selection: .constant("medium")),
                        color: FrontendColors.stateFanActiveColor.color
                    )
                },
                .init("Percentage with power") {
                    HAMoreInfoFan(
                        state: "40%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-600),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        speed: .percentage(.constant(40), powerLabel: "Toggle"),
                        color: FrontendColors.stateFanActiveColor.color
                    )
                },
            ]
        case .moreInfoCover:
            [
                .init("Buttons") {
                    HAMoreInfoCover(
                        state: "Open",
                        lastChanged: Self.sampleDate.addingTimeInterval(-300),
                        now: Self.sampleDate,
                        color: FrontendColors.stateCoverActiveColor.color,
                        buttons: HAStateControlCoverButtons(
                            open: Self.sampleCoverOpen,
                            stop: Self.sampleCoverStop,
                            close: Self.sampleCoverClose
                        )
                    )
                },
                .init("Position, with buttons") {
                    HAMoreInfoCover(
                        state: "Open · 50%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-3060),
                        now: Self.sampleDate,
                        color: FrontendColors.stateCoverActiveColor.color,
                        position: .constant(50),
                        buttons: HAStateControlCoverButtons(
                            open: Self.sampleCoverOpen,
                            stop: Self.sampleCoverStop,
                            close: Self.sampleCoverClose
                        )
                    )
                },
                .init("Position and tilt") {
                    HAMoreInfoCover(
                        state: "Open · 30%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-33),
                        now: Self.sampleDate,
                        color: FrontendColors.stateCoverActiveColor.color,
                        position: .constant(30),
                        tiltPosition: .constant(70)
                    )
                },
                .init("Open/close only") {
                    HAMoreInfoCover(
                        state: "Closed",
                        lastChanged: Self.sampleDate.addingTimeInterval(-900),
                        now: Self.sampleDate,
                        color: .haDisabled,
                        toggle: .constant(false)
                    )
                },
            ]
        case .moreInfoLock:
            [
                .init("Locked, can open") {
                    HAMoreInfoLock(
                        state: "Locked",
                        lastChanged: Self.sampleDate.addingTimeInterval(-420),
                        now: Self.sampleDate,
                        isLocked: .constant(true),
                        color: FrontendColors.stateLockLockedColor.color,
                        onOpen: {}
                    )
                },
                .init("Jammed") {
                    HAMoreInfoLock(
                        state: "Jammed",
                        lastChanged: Self.sampleDate.addingTimeInterval(-60),
                        now: Self.sampleDate,
                        isLocked: .constant(false),
                        color: FrontendColors.stateLockJammedColor.color,
                        isJammed: true
                    )
                },
                .init("Unavailable") {
                    HAMoreInfoLock(
                        state: "Unavailable",
                        lastChanged: Self.sampleDate.addingTimeInterval(-3600),
                        now: Self.sampleDate,
                        isLocked: .constant(false),
                        color: .haDisabled,
                        isUnavailable: true
                    )
                },
            ]
        case .moreInfoLawnMower:
            [
                .init("Mowing") {
                    HAMoreInfoLawnMower(
                        state: "Mowing",
                        lastChanged: Self.sampleDate.addingTimeInterval(-600),
                        now: Self.sampleDate,
                        visualState: .active,
                        color: FrontendColors.stateLawnMowerActiveColor.color,
                        battery: HAMoreInfoBattery(level: 72),
                        commands: Self.sampleMowerCommands(isMowing: true)
                    )
                },
                .init("Docked") {
                    HAMoreInfoLawnMower(
                        state: "Docked",
                        lastChanged: Self.sampleDate.addingTimeInterval(-1140),
                        now: Self.sampleDate,
                        visualState: .docked,
                        color: .haDisabled,
                        battery: HAMoreInfoBattery(level: 100, isCharging: true),
                        commands: Self.sampleMowerCommands(isMowing: false)
                    )
                },
            ]
        case .moreInfoVacuum:
            [
                .init("Cleaning") {
                    HAMoreInfoVacuum(
                        state: "Cleaning bedroom",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2460),
                        now: Self.sampleDate,
                        visualState: .active,
                        color: FrontendColors.stateVacuumActiveColor.color,
                        battery: HAMoreInfoBattery(level: 64),
                        commands: Self.sampleVacuumCommands(isCleaning: true),
                        selects: [Self.sampleVacuumFanSpeedSelect],
                        onCleanAreas: {}
                    )
                },
                .init("Error") {
                    HAMoreInfoVacuum(
                        state: "Error",
                        lastChanged: Self.sampleDate.addingTimeInterval(-720),
                        now: Self.sampleDate,
                        visualState: .error,
                        color: FrontendColors.stateVacuumErrorColor.color,
                        commands: Self.sampleVacuumCommands(isCleaning: false)
                    )
                },
            ]
        case .moreInfoLight:
            [
                .init("On/off only") {
                    HAMoreInfoLight(
                        state: "On",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2040),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        color: FrontendColors.stateLightActiveColor.color
                    )
                },
                .init("Dimmable") {
                    HAMoreInfoLight(
                        state: "78%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-540),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        color: FrontendColors.stateLightActiveColor.color,
                        brightness: .constant(78)
                    )
                },
                .init("Colour, temperature and effects") {
                    HAMoreInfoLight(
                        state: "100%",
                        lastChanged: Self.sampleDate.addingTimeInterval(-3480),
                        now: Self.sampleDate,
                        isOn: .constant(true),
                        color: Color(.sRGB, red: 0.1, green: 0.3, blue: 1),
                        brightness: .constant(100),
                        hue: .constant(225),
                        saturation: .constant(0.9),
                        colorTemperature: .constant(4000),
                        onSetWhite: {},
                        selects: [Self.sampleEffectSelect]
                    )
                },
            ]
        case .moreInfoScene:
            [
                .init("Can be activated") {
                    HAMoreInfoScene(
                        name: "Romantic scene",
                        lastChanged: Self.sampleDate.addingTimeInterval(-600),
                        now: Self.sampleDate
                    ) {}
                },
                .init("Unavailable") {
                    HAMoreInfoScene(
                        name: "Romantic scene",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2400),
                        now: Self.sampleDate,
                        unavailableState: "Unavailable"
                    ) {}
                },
            ]
        case .moreInfoMediaPlayer:
            [
                .init("Playing") {
                    HAMoreInfoMediaPlayer(
                        state: "Playing",
                        isPlaying: true,
                        title: "Epic sax guy 10 hours",
                        artist: "YouTube",
                        position: .constant(1840),
                        duration: 36000,
                        onPlayPause: {},
                        onPrevious: {},
                        onNext: {},
                        shuffle: .constant(false),
                        repeatMode: .constant(.all),
                        volume: .constant(0.6),
                        isMuted: .constant(false),
                        commands: [
                            HAMoreInfoCommand(id: "browse", icon: .playBoxMultipleIcon, label: "Browse media") {},
                            HAMoreInfoCommand(id: "join", icon: .speakerMultipleIcon, label: "Join") {},
                            HAMoreInfoCommand(id: "off", icon: .powerIcon, label: "Turn off") {},
                        ],
                        selects: [
                            HAMoreInfoSelect(
                                id: "source",
                                label: "Source",
                                icon: .loginVariantIcon,
                                options: [.init(id: "tv", label: "TV"), .init(id: "radio", label: "Radio")],
                                selection: .constant("tv")
                            ),
                        ]
                    )
                },
                .init("Stepped volume, nothing playing") {
                    HAMoreInfoMediaPlayer(
                        state: "Idle",
                        onPlayPause: {},
                        onVolumeDown: {},
                        onVolumeUp: {},
                        commands: [HAMoreInfoCommand(id: "off", icon: .powerIcon, label: "Turn off") {}]
                    )
                },
                .init("Unavailable") {
                    HAMoreInfoMediaPlayer(state: "Unavailable", isUnavailable: true)
                },
            ]
        case .moreInfoNumber:
            [
                .init("Slider") {
                    HAMoreInfoNumber(
                        name: "Slider",
                        lastChanged: Self.sampleDate.addingTimeInterval(-360),
                        now: Self.sampleDate,
                        value: .constant(40),
                        scale: HASliderScale(min: 0, max: 100, step: 1),
                        unit: "items"
                    )
                },
                .init("Box") {
                    HAMoreInfoNumber(
                        name: "Box",
                        lastChanged: Self.sampleDate.addingTimeInterval(-1200),
                        now: Self.sampleDate,
                        value: .constant(0),
                        scale: HASliderScale(min: 0, max: 100, step: 0.5),
                        unit: "items",
                        mode: .box
                    )
                },
            ]
        case .moreInfoText:
            [
                .init("Text") {
                    HAMoreInfoText(
                        name: "Text",
                        lastChanged: Self.sampleDate.addingTimeInterval(-60),
                        now: Self.sampleDate,
                        text: .constant("Hello world")
                    )
                },
                .init("Password") {
                    HAMoreInfoText(
                        name: "Password",
                        lastChanged: Self.sampleDate.addingTimeInterval(-600),
                        now: Self.sampleDate,
                        text: .constant("secret"),
                        isPassword: true
                    )
                },
            ]
        case .moreInfoTimer:
            HAMoreInfoTimer.Status.allCases.map { status in
                .init(status.rawValue.capitalized) {
                    HAMoreInfoTimer(
                        display: status == .idle ? "Idle" : status == .paused ? "0:04:59 (Paused)" : "0:04:59",
                        lastChanged: Self.sampleDate.addingTimeInterval(-1500),
                        now: Self.sampleDate,
                        state: status,
                        duration: .constant(HATimeComponents(minutes: 5)),
                        onStart: {},
                        onPause: {},
                        onResume: {},
                        onCancel: {},
                        onFinish: {}
                    )
                }
            }
        case .moreInfoUpdate:
            [
                .init("Update available, with backup") {
                    HAMoreInfoUpdate(
                        name: "Home Assistant Core",
                        lastChanged: Self.sampleDate.addingTimeInterval(-22),
                        now: Self.sampleDate,
                        state: "Update available",
                        title: "Home Assistant Core",
                        versions: Self.sampleUpdateVersions,
                        releaseURL: URL(string: "https://www.home-assistant.io"),
                        releaseNotes: "## What's new\n- Faster startup\n- Bug fixes",
                        backup: .init(
                            title: "Create backup",
                            description: "Back up before updating",
                            isOn: .constant(true)
                        ),
                        onSkip: {},
                        onClearSkipped: {},
                        onInstall: {}
                    )
                },
                .init("Installing") {
                    HAMoreInfoUpdate(
                        name: "With 50 in_progress",
                        lastChanged: Self.sampleDate.addingTimeInterval(-2280),
                        now: Self.sampleDate,
                        state: "Installing (50%)",
                        versions: Self.sampleUpdateVersions,
                        isInstalling: true,
                        progress: 50,
                        onSkip: {},
                        onClearSkipped: {},
                        onInstall: {}
                    )
                },
                .init("Skipped version") {
                    HAMoreInfoUpdate(
                        name: "Skipped version",
                        icon: .packageIcon,
                        color: .haDisabled,
                        lastChanged: Self.sampleDate.addingTimeInterval(-3600),
                        now: Self.sampleDate,
                        state: "Up-to-date",
                        versions: Self.sampleUpdateVersions,
                        isSkipped: true,
                        canInstall: false,
                        onSkip: {},
                        onClearSkipped: {},
                        onInstall: {}
                    )
                },
            ]
        default:
            []
        }
    }

    private static let sampleClimateScale = HACircularSliderScale(min: 10, max: 30, step: 0.5)

    private static let sampleTemperatureReadings = [HAMoreInfoReading(label: "Current temperature", value: "18 °C")]

    private static let sampleUpdateVersions: [HAMoreInfoUpdate.Version] = [
        .init(label: "Installed version", value: "2026.10.1"),
        .init(label: "Latest version", value: "2026.10.2"),
    ]

    private static let sampleFanSpeeds: [HAControlSelectOption] = [
        .init(id: "high", label: "High", icon: .fanSpeed3Icon),
        .init(id: "medium", label: "Medium", icon: .fanSpeed2Icon),
        .init(id: "low", label: "Low", icon: .fanSpeed1Icon),
        .init(id: "off", label: "Off", icon: .fanOffIcon),
    ]

    private static func sampleModeSelect(selection: String?) -> HAMoreInfoSelect {
        HAMoreInfoSelect(
            id: "mode",
            label: "Mode",
            icon: .thermostatIcon,
            options: [
                .init(id: "auto", label: "Auto", icon: .thermostatAutoIcon),
                .init(id: "heat", label: "Heat", icon: .fireIcon),
                .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
                .init(id: "fan_only", label: "Fan only", icon: .fanIcon),
                .init(id: "off", label: "Off", icon: .powerIcon),
            ],
            selection: .constant(selection)
        )
    }

    private static func sampleOnOffSelect(selection: String) -> HAMoreInfoSelect {
        HAMoreInfoSelect(
            id: "state",
            label: "State",
            icon: .powerIcon,
            options: [.init(id: "off", label: "Off"), .init(id: "on", label: "On")],
            selection: .constant(selection)
        )
    }

    private static let samplePresetSelect = HAMoreInfoSelect(
        id: "preset",
        label: "Preset",
        icon: .tuneVariantIcon,
        options: [.init(id: "eco", label: "Eco", icon: .leafIcon), .init(id: "comfort", label: "Comfort")],
        selection: .constant("eco")
    )

    private static let sampleFanModeSelect = HAMoreInfoSelect(
        id: "fan_mode",
        label: "Fan mode",
        icon: .fanIcon,
        options: [.init(id: "low", label: "Low"), .init(id: "high", label: "High")],
        selection: .constant("low")
    )

    private static let sampleSwingSelect = HAMoreInfoSelect(
        id: "swing_mode",
        label: "Swing mode",
        icon: .arrowOscillatingIcon,
        options: [.init(id: "on", label: "On"), .init(id: "off", label: "Off")],
        selection: .constant("off")
    )

    private static let sampleOscillatingSelect = HAMoreInfoSelect(
        id: "oscillating",
        label: "Oscillating",
        icon: .arrowOscillatingOffIcon,
        options: [
            .init(id: "true", label: "Yes", icon: .arrowOscillatingIcon),
            .init(id: "false", label: "No", icon: .arrowOscillatingOffIcon),
        ],
        selection: .constant("false")
    )

    private static let sampleHumidifierModeSelect = HAMoreInfoSelect(
        id: "mode",
        label: "Mode",
        icon: .tuneVariantIcon,
        options: [.init(id: "normal", label: "Normal"), .init(id: "eco", label: "Eco", icon: .leafIcon)],
        selection: .constant("normal")
    )

    private static let sampleWaterHeaterModeSelect = HAMoreInfoSelect(
        id: "mode",
        label: "Mode",
        icon: .waterBoilerIcon,
        options: [.init(id: "eco", label: "Eco", icon: .leafIcon), .init(id: "electric", label: "Electric")],
        selection: .constant("eco")
    )

    private static let sampleAwaySelect = HAMoreInfoSelect(
        id: "away_mode",
        label: "Away mode",
        icon: .accountIcon,
        options: [
            .init(id: "on", label: "On", icon: .accountArrowRightIcon),
            .init(id: "off", label: "Off", icon: .accountIcon),
        ],
        selection: .constant("off")
    )

    private static let sampleVacuumFanSpeedSelect = HAMoreInfoSelect(
        id: "fan_speed",
        label: "Fan speed",
        icon: .fanIcon,
        options: [.init(id: "balanced", label: "balanced"), .init(id: "turbo", label: "turbo")],
        selection: .constant("turbo")
    )

    private static let sampleEffectSelect = HAMoreInfoSelect(
        id: "effect",
        label: "Effect",
        icon: .creationIcon,
        options: [.init(id: "rainbow", label: "Rainbow"), .init(id: "colorloop", label: "Colorloop")],
        selection: .constant(nil)
    )

    private static let sampleCoverOpen = HAMoreInfoCommand(id: "open", icon: .arrowUpIcon, label: "Open") {}
    private static let sampleCoverStop = HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop") {}
    private static let sampleCoverClose = HAMoreInfoCommand(id: "close", icon: .arrowDownIcon, label: "Close") {}
    private static let sampleCoverOpenTilt = HAMoreInfoCommand(
        id: "open-tilt",
        icon: .arrowTopRightIcon,
        label: "Open tilt"
    ) {}
    private static let sampleCoverCloseTilt = HAMoreInfoCommand(
        id: "close-tilt",
        icon: .arrowBottomLeftIcon,
        label: "Close tilt"
    ) {}

    private static func sampleVacuumColor(_ state: HARobotVisualState) -> Color {
        switch state {
        case .error: FrontendColors.stateVacuumErrorColor.color
        case .active, .returning: FrontendColors.stateVacuumActiveColor.color
        case .idle, .paused, .docked: .haDisabled
        }
    }

    private static func sampleVacuumCommands(isCleaning: Bool) -> [HAMoreInfoCommand] {
        [
            HAMoreInfoCommand(
                id: "start",
                icon: isCleaning ? .pauseIcon : .playIcon,
                label: isCleaning ? "Pause" : "Start"
            ) {},
            HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop", isDisabled: !isCleaning) {},
            HAMoreInfoCommand(id: "dock", icon: .homeImportOutlineIcon, label: "Return to dock") {},
            HAMoreInfoCommand(id: "locate", icon: .mapMarkerIcon, label: "Locate") {},
            HAMoreInfoCommand(id: "spot", icon: .targetVariantIcon, label: "Clean spot") {},
        ]
    }

    private static func sampleMowerCommands(isMowing: Bool) -> [HAMoreInfoCommand] {
        [
            HAMoreInfoCommand(
                id: "start",
                icon: isMowing ? .pauseIcon : .playIcon,
                label: isMowing ? "Pause" : "Start"
            ) {},
            HAMoreInfoCommand(id: "stop", icon: .stopIcon, label: "Stop", isDisabled: !isMowing) {},
            HAMoreInfoCommand(id: "dock", icon: .homeImportOutlineIcon, label: "Dock", isDisabled: !isMowing) {},
        ]
    }
}
#endif
