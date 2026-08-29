#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// Every component in the design system, as shown by `ComponentsLibraryView` and captured by the
/// gallery snapshot test.
///
/// A component lists a ``DesignSystemComponentVariant`` per capability it has, so the library is the
/// specification of what each component supports and no capability ships undemonstrated.
///
/// Frontend counterpart: the page index of the frontend's `gallery/` package. Gallery scaffolding,
/// not a component. Which frontend element each case corresponds to is documented on the component
/// type itself; `FRONTEND_PARITY.md` maps the set as a whole.
public enum DesignSystemComponent: String, CaseIterable, Identifiable {
    case primaryButton
    case secondaryButton
    case outlinedButton
    case neutralButton
    case negativeButton
    case secondaryNegativeButton
    case criticalButton
    case linkButton
    case textButton
    case closeButton
    case sheetCloseButton
    case textField
    case card
    case bottomSheet
    case floatingPanel
    case progressView
    case fullScreenLoader
    case pill
    case alert
    case bar
    case metric
    case emptyState
    case sectionTitle
    case tip
    case label
    case bigNumber
    case treeIndicator
    case badge
    case segmentedBar
    case settingsRow
    case marqueeText
    case faded
    case progressRing
    case collapsible
    case assistChip
    case filterChip
    case inputChip
    case buttonToggleGroup
    case iconButtonToggle
    case progressButton
    case controlSlider
    case controlSwitch
    case controlButton
    case controlButtonGroup
    case gauge
    case controlSelect
    case controlNumberButtons
    case controlCircularSlider
    case selectBox
    case haCard
    case tileIcon
    case tileBadge
    case tileInfo
    case tileCard
    case entityCard
    case buttonCard
    case glanceCard
    case gaugeCard
    case markdownCard
    case headingCard
    case clockCard
    case thermostatCard
    case todoListCard
    case weatherForecastCard
    case pictureCard
    case alarmPanelCard
    case tabGroup
    case iconButtonGroup
    case statisticCard
    case humidifierCard
    case pictureGlanceCard
    case historyChart
    case historyTimeline
    case historyGraphCard
    case statisticsChart
    case statisticsGraphCard
    case energyDistributionCard
    case toast
    case progressBar
    case labelBadge
    case hsColorPicker
    case formField
    case headingBadge
    case dialogHeader
    case relativeTime
    case sankeyChart
    case sunburstChart
    case energySourcesTable
    case energyPeriodSelector
    case entityRow
    case entitiesCard
    case lightCard
    case baseTimeInput
    case timeInput
    case durationInput
    case dateInput
    case absoluteTime
    case markdownText
    case qrCode
    case qrScanner
    case sparkline
    case analogClock
    case errorCard
    case sensorCard
    case logbookCard
    case mediaControlCard
    case plantStatusCard
    case calendarCard
    case areaCard
    case distributionCard
    case assistVoiceOrb

    /// The `home-assistant/frontend` element this component is the counterpart of, or `nil` when it
    /// has none and is the app's own.
    ///
    /// Read from the component's own ``FrontendComponent`` conformance rather than repeated here, so
    /// the element name has exactly one home. Generic view types are specialised with `AnyView`
    /// only because a static member cannot be read off an unbound generic — the argument is never
    /// used.
    public var frontendComponentName: String? {
        switch self {
        case .primaryButton: HAButtonStyle.frontendComponentName
        case .secondaryButton: HAButtonStyle.frontendComponentName
        case .outlinedButton: HAButtonStyle.frontendComponentName
        case .neutralButton: HAButtonStyle.frontendComponentName
        case .negativeButton: HAButtonStyle.frontendComponentName
        case .secondaryNegativeButton: HAButtonStyle.frontendComponentName
        case .criticalButton: HAButtonStyle.frontendComponentName
        case .linkButton: HAButtonStyle.frontendComponentName
        case .textButton: TextButton.frontendComponentName
        case .closeButton: CloseButton.frontendComponentName
        case .sheetCloseButton: SheetCloseButton.frontendComponentName
        case .textField: HATextField.frontendComponentName
        case .card: nil
        case .bottomSheet: AppleLikeBottomSheet<AnyView>.frontendComponentName
        case .floatingPanel: nil
        case .progressView: HAProgressView.frontendComponentName
        case .fullScreenLoader: nil
        case .pill: nil
        case .alert: HAAlertView<AnyView, AnyView>.frontendComponentName
        case .bar: HABar.frontendComponentName
        case .metric: HAMetric.frontendComponentName
        case .emptyState: HAEmptyStateView<AnyView>.frontendComponentName
        case .sectionTitle: HASectionTitle.frontendComponentName
        case .tip: HATipView.frontendComponentName
        case .label: HALabel.frontendComponentName
        case .bigNumber: HABigNumber.frontendComponentName
        case .treeIndicator: HATreeIndicator.frontendComponentName
        case .badge: HABadge<AnyView>.frontendComponentName
        case .segmentedBar: HASegmentedBar.frontendComponentName
        case .settingsRow: HASettingsRow<AnyView, AnyView>.frontendComponentName
        case .marqueeText: HAMarqueeText.frontendComponentName
        case .faded: HAFadedView<AnyView>.frontendComponentName
        case .progressRing: HAProgressRing.frontendComponentName
        case .collapsible: CollapsibleView<AnyView, AnyView>.frontendComponentName
        case .assistChip: HAAssistChip.frontendComponentName
        case .filterChip: HAFilterChip.frontendComponentName
        case .inputChip: HAInputChip.frontendComponentName
        case .buttonToggleGroup: HAButtonToggleGroup.frontendComponentName
        case .iconButtonToggle: HAIconButtonToggle.frontendComponentName
        case .progressButton: HAProgressButton.frontendComponentName
        case .controlSlider: HAControlSlider.frontendComponentName
        case .controlSwitch: HAControlSwitch.frontendComponentName
        case .controlButton: HAControlButton.frontendComponentName
        case .controlButtonGroup: HAControlButtonGroup<AnyView>.frontendComponentName
        case .gauge: HAGauge.frontendComponentName
        case .controlSelect: HAControlSelect.frontendComponentName
        case .controlNumberButtons: HAControlNumberButtons.frontendComponentName
        case .controlCircularSlider: HAControlCircularSlider.frontendComponentName
        case .selectBox: HASelectBox.frontendComponentName
        case .haCard: HACard<AnyView>.frontendComponentName
        case .tileIcon: HATileIcon<AnyView>.frontendComponentName
        case .tileBadge: HATileBadge.frontendComponentName
        case .tileInfo: HATileInfo.frontendComponentName
        case .tileCard: HATileCard<AnyView>.frontendComponentName
        case .entityCard: HAEntityCard.frontendComponentName
        case .buttonCard: HAButtonCard.frontendComponentName
        case .glanceCard: HAGlanceCard.frontendComponentName
        case .gaugeCard: HAGaugeCard.frontendComponentName
        case .markdownCard: HAMarkdownCard.frontendComponentName
        case .headingCard: HAHeadingCard<AnyView>.frontendComponentName
        case .clockCard: HAClockCard.frontendComponentName
        case .thermostatCard: HAThermostatCard<AnyView>.frontendComponentName
        case .todoListCard: HATodoListCard.frontendComponentName
        case .weatherForecastCard: HAWeatherForecastCard.frontendComponentName
        case .pictureCard: HAPictureCard<AnyView>.frontendComponentName
        case .alarmPanelCard: HAAlarmPanelCard.frontendComponentName
        case .tabGroup: HATabGroup.frontendComponentName
        case .iconButtonGroup: HAIconButtonGroup<AnyView>.frontendComponentName
        case .statisticCard: HAStatisticCard.frontendComponentName
        case .humidifierCard: HAHumidifierCard<AnyView>.frontendComponentName
        case .pictureGlanceCard: HAPictureGlanceCard.frontendComponentName
        case .historyChart: HAHistoryChart.frontendComponentName
        case .historyTimeline: HAHistoryTimeline.frontendComponentName
        case .historyGraphCard: HAHistoryGraphCard.frontendComponentName
        case .statisticsChart: HAStatisticsChart.frontendComponentName
        case .statisticsGraphCard: HAStatisticsGraphCard.frontendComponentName
        case .energyDistributionCard: HAEnergyDistributionCard.frontendComponentName
        case .toast: HAToast.frontendComponentName
        case .progressBar: HAProgressBar.frontendComponentName
        case .labelBadge: HALabelBadge.frontendComponentName
        case .hsColorPicker: HAHSColorPicker.frontendComponentName
        case .formField: HAFormField<AnyView>.frontendComponentName
        case .headingBadge: HAHeadingBadge.frontendComponentName
        case .dialogHeader: HADialogHeader<AnyView>.frontendComponentName
        case .relativeTime: HARelativeTime.frontendComponentName
        case .sankeyChart: HASankeyChart.frontendComponentName
        case .sunburstChart: HASunburstChart.frontendComponentName
        case .energySourcesTable: HAEnergySourcesTable.frontendComponentName
        case .energyPeriodSelector: HAEnergyPeriodSelector.frontendComponentName
        case .entityRow: HAEntityRow<AnyView>.frontendComponentName
        case .entitiesCard: HAEntitiesCard<AnyView>.frontendComponentName
        case .lightCard: HALightCard.frontendComponentName
        case .baseTimeInput: HABaseTimeInput.frontendComponentName
        case .timeInput: HATimeInput.frontendComponentName
        case .durationInput: HADurationInput.frontendComponentName
        case .dateInput: HADateInput.frontendComponentName
        case .absoluteTime: HAAbsoluteTime.frontendComponentName
        case .markdownText: HAMarkdownText.frontendComponentName
        case .qrCode: HAQRCode.frontendComponentName
        case .qrScanner: HAQRScanner.frontendComponentName
        case .sparkline: HASparkline.frontendComponentName
        case .analogClock: HAAnalogClock.frontendComponentName
        case .errorCard: HAErrorCard.frontendComponentName
        case .sensorCard: HASensorCard.frontendComponentName
        case .logbookCard: HALogbookCard.frontendComponentName
        case .mediaControlCard: HAMediaControlCard.frontendComponentName
        case .plantStatusCard: HAPlantStatusCard.frontendComponentName
        case .calendarCard: HACalendarCard.frontendComponentName
        case .areaCard: HAAreaCard.frontendComponentName
        case .distributionCard: HADistributionCard.frontendComponentName
        case .assistVoiceOrb: nil
        }
    }

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .primaryButton: "Primary Button"
        case .secondaryButton: "Secondary Button"
        case .outlinedButton: "Outlined Button"
        case .neutralButton: "Neutral Button"
        case .negativeButton: "Negative Button"
        case .secondaryNegativeButton: "Secondary Negative Button"
        case .criticalButton: "Critical Button"
        case .linkButton: "Link Button"
        case .textButton: "Text Button"
        case .closeButton: "Close Button"
        case .sheetCloseButton: "Sheet Close Button"
        case .textField: "Text Field"
        case .card: "Card"
        case .bottomSheet: "Bottom Sheet"
        case .floatingPanel: "Floating Panel"
        case .progressView: "Progress View"
        case .fullScreenLoader: "Full Screen Loader"
        case .pill: "Pill"
        case .alert: "Alert"
        case .bar: "Bar"
        case .metric: "Metric"
        case .emptyState: "Empty State"
        case .sectionTitle: "Section Title"
        case .tip: "Tip"
        case .label: "Label"
        case .bigNumber: "Big Number"
        case .treeIndicator: "Tree Indicator"
        case .badge: "Badge"
        case .segmentedBar: "Segmented Bar"
        case .settingsRow: "Settings Row"
        case .marqueeText: "Marquee Text"
        case .faded: "Faded"
        case .progressRing: "Progress Ring"
        case .collapsible: "Collapsible"
        case .assistChip: "Assist Chip"
        case .filterChip: "Filter Chip"
        case .inputChip: "Input Chip"
        case .buttonToggleGroup: "Button Toggle Group"
        case .iconButtonToggle: "Icon Button Toggle"
        case .progressButton: "Progress Button"
        case .controlSlider: "Control Slider"
        case .controlSwitch: "Control Switch"
        case .controlButton: "Control Button"
        case .controlButtonGroup: "Control Button Group"
        case .gauge: "Gauge"
        case .controlSelect: "Control Select"
        case .controlNumberButtons: "Control Number Buttons"
        case .controlCircularSlider: "Control Circular Slider"
        case .selectBox: "Select Box"
        case .haCard: "HA Card"
        case .tileIcon: "Tile Icon"
        case .tileBadge: "Tile Badge"
        case .tileInfo: "Tile Info"
        case .tileCard: "Tile Card"
        case .entityCard: "Entity Card"
        case .buttonCard: "Button Card"
        case .glanceCard: "Glance Card"
        case .gaugeCard: "Gauge Card"
        case .markdownCard: "Markdown Card"
        case .headingCard: "Heading Card"
        case .clockCard: "Clock Card"
        case .thermostatCard: "Thermostat Card"
        case .todoListCard: "To-do List Card"
        case .weatherForecastCard: "Weather Forecast Card"
        case .pictureCard: "Picture Card"
        case .alarmPanelCard: "Alarm Panel Card"
        case .tabGroup: "Tab Group"
        case .iconButtonGroup: "Icon Button Group"
        case .statisticCard: "Statistic Card"
        case .humidifierCard: "Humidifier Card"
        case .pictureGlanceCard: "Picture Glance Card"
        case .historyChart: "History Chart"
        case .historyTimeline: "History Timeline"
        case .historyGraphCard: "History Graph Card"
        case .statisticsChart: "Statistics Chart"
        case .statisticsGraphCard: "Statistics Graph Card"
        case .energyDistributionCard: "Energy Distribution Card"
        case .toast: "Toast"
        case .progressBar: "Progress Bar"
        case .labelBadge: "Label Badge"
        case .hsColorPicker: "HS Color Picker"
        case .formField: "Form Field"
        case .headingBadge: "Heading Badge"
        case .dialogHeader: "Dialog Header"
        case .relativeTime: "Relative Time"
        case .sankeyChart: "Sankey Chart"
        case .sunburstChart: "Sunburst Chart"
        case .energySourcesTable: "Energy Sources Table"
        case .energyPeriodSelector: "Energy Period Selector"
        case .entityRow: "Entity Row"
        case .entitiesCard: "Entities Card"
        case .lightCard: "Light Card"
        case .baseTimeInput: "Base Time Input"
        case .timeInput: "Time Input"
        case .durationInput: "Duration Input"
        case .dateInput: "Date Input"
        case .absoluteTime: "Absolute Time"
        case .markdownText: "Markdown"
        case .qrCode: "QR Code"
        case .qrScanner: "QR Scanner"
        case .sparkline: "Sparkline"
        case .analogClock: "Analog Clock"
        case .errorCard: "Error Card"
        case .sensorCard: "Sensor Card"
        case .logbookCard: "Logbook Card"
        case .mediaControlCard: "Media Control Card"
        case .plantStatusCard: "Plant Status Card"
        case .calendarCard: "Calendar Card"
        case .areaCard: "Area Card"
        case .distributionCard: "Distribution Card"
        case .assistVoiceOrb: "Assist Voice Orb"
        }
    }

    public var category: ComponentCategory {
        switch self {
        case .primaryButton, .secondaryButton, .outlinedButton, .neutralButton, .negativeButton,
             .secondaryNegativeButton, .criticalButton, .linkButton, .textButton:
            .buttons
        case .closeButton, .sheetCloseButton, .controlSlider, .controlSwitch, .controlButton,
             .controlButtonGroup, .gauge, .controlSelect, .controlNumberButtons,
             .controlCircularSlider, .hsColorPicker:
            .controls
        case .textField, .selectBox, .formField, .baseTimeInput, .timeInput, .durationInput,
             .dateInput, .qrScanner:
            .inputs
        case .card, .bottomSheet, .floatingPanel, .sectionTitle, .settingsRow, .faded, .collapsible,
             .haCard, .tileCard, .entityCard, .buttonCard, .glanceCard, .gaugeCard, .markdownCard,
             .headingCard, .clockCard, .thermostatCard, .todoListCard, .weatherForecastCard, .dialogHeader,
             .pictureCard, .alarmPanelCard, .statisticCard, .humidifierCard, .pictureGlanceCard,
             .historyGraphCard, .statisticsGraphCard, .energyDistributionCard, .energySourcesTable,
             .energyPeriodSelector, .entityRow, .entitiesCard, .lightCard, .errorCard, .sensorCard,
             .logbookCard, .mediaControlCard, .plantStatusCard, .calendarCard, .areaCard,
             .distributionCard:
            .containers
        case .progressView, .fullScreenLoader, .pill, .bar, .progressRing, .progressBar,
             .assistVoiceOrb:
            .indicators
        case .alert, .emptyState, .tip, .toast:
            .feedback
        case .assistChip, .filterChip, .inputChip, .buttonToggleGroup, .iconButtonToggle,
             .progressButton, .tabGroup, .iconButtonGroup:
            .buttons
        case .metric, .label, .bigNumber, .treeIndicator, .badge, .segmentedBar, .marqueeText,
             .tileIcon, .tileBadge, .tileInfo, .historyChart, .historyTimeline, .statisticsChart,
             .labelBadge, .headingBadge, .relativeTime, .sankeyChart, .sunburstChart, .absoluteTime,
             .markdownText, .qrCode, .sparkline, .analogClock:
            .dataDisplay
        }
    }

    public var variants: [DesignSystemComponentVariant] {
        switch self {
        case .primaryButton:
            buttonVariants { $0.buttonStyle(.primaryButton) }
        case .secondaryButton:
            buttonVariants { $0.buttonStyle(.secondaryButton) }
        case .outlinedButton:
            buttonVariants { $0.buttonStyle(.outlinedButton) }
        case .neutralButton:
            buttonVariants { $0.buttonStyle(.neutralButton) }
        case .negativeButton:
            buttonVariants { $0.buttonStyle(.negativeButton) }
        case .secondaryNegativeButton:
            buttonVariants { $0.buttonStyle(.secondaryNegativeButton) }
        case .criticalButton:
            buttonVariants { $0.buttonStyle(.criticalButton) }
        case .linkButton:
            buttonVariants { $0.buttonStyle(.linkButton) }
        case .textButton:
            buttonVariants { $0.buttonStyle(.textButton) }
        case .closeButton:
            [
                .init("Small") { CloseButton(size: .small) {} },
                .init("Medium") { CloseButton(size: .medium) {} },
                .init("Large") { CloseButton(size: .large) {} },
                .init("Tinted") { CloseButton(tint: .haErrorColor, size: .medium) {} },
            ]
        case .sheetCloseButton:
            [.init("Default") { SheetCloseButton {} }]
        case .textField:
            [
                .init("With value") { HATextField(placeholder: "Placeholder", text: .constant("Example")) },
                .init("Empty") { HATextField(placeholder: "Placeholder", text: .constant("")) },
            ]
        case .card:
            [
                .init("Default") { CardView { Text("Card content").frame(maxWidth: .infinity, alignment: .leading) } },
                .init("Tinted background") {
                    CardView(backgroundColor: .haPrimary.opacity(0.1)) {
                        Text("Card content").frame(maxWidth: .infinity, alignment: .leading)
                    }
                },
            ]
        case .bottomSheet:
            [.init("Default") { BottomSheetGalleryDemo() }]
        case .floatingPanel:
            [.init("Default") {
                Color.clear
                    .frame(height: 320)
                    .overlay {
                        FloatingPanel(initialCorner: .topTrailing) {
                            Text("Drag me").padding()
                        }
                    }
            }]
        case .progressView:
            [.init("Medium") { HAProgressView(style: .medium) }]
        case .fullScreenLoader:
            [.init("Default") {
                ZStack {
                    LinearGradient(
                        colors: [.blue, .purple, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    FullScreenLoaderView(
                        logo: Image(systemSymbol: .houseFill),
                        retryTitle: "Retry",
                        controlsRevealDelay: 2,
                        settingsAction: {},
                        retryAction: {}
                    )
                }
                .frame(height: 420)
                .clipped()
            }]
        case .pill:
            [
                .init("Selected") { PillView(text: "Selected", selected: true) },
                .init("Normal") { PillView(text: "Normal", selected: false) },
            ]
        case .alert:
            HAAlertType.allCases.map { type in
                .init(type.rawValue.capitalized) {
                    HAAlertView("Something happened that you should know about.", alertType: type)
                }
            } + [
                .init("With title") {
                    HAAlertView("The connection dropped and was restored.", title: "Reconnected", alertType: .success)
                },
                .init("Dismissable") {
                    HAAlertView("Your token expires tomorrow.", alertType: .warning, onDismiss: {})
                },
                .init("With action") {
                    HAAlertView(alertType: .error) {
                        Text("The server refused the request.")
                    } action: {
                        Button("Retry") {}.buttonStyle(.textButton)
                    }
                },
                .init("Narrow") {
                    HAAlertView(alertType: .info, narrow: true) {
                        Text("Narrow puts the action on its own line.")
                    } action: {
                        Button("Details") {}.buttonStyle(.textButton)
                    }
                },
                .init("Custom icon") {
                    HAAlertView("An icon other than the type's default.", alertType: .info, icon: .lightbulbOutlineIcon)
                },
            ]
        case .bar:
            [
                .init("Empty") { HABar(value: 0) },
                .init("Partial") { HABar(value: 35) },
                .init("Full") { HABar(value: 100) },
                .init("Above maximum, clamped") { HABar(value: 150, tint: .haErrorColor) },
                .init("Custom range") { HABar(value: 12, min: 10, max: 20, tint: .haSuccessColor) },
            ]
        case .metric:
            [
                .init("Below warning threshold") { HAMetric(heading: "Memory usage", value: 12.4) },
                .init("Above warning threshold") { HAMetric(heading: "Disk usage", value: 67) },
                .init("Above critical threshold") { HAMetric(heading: "CPU usage", value: 93.8) },
            ]
        case .emptyState:
            [
                .init("With action") {
                    HAEmptyStateView(
                        icon: .packageVariantIcon,
                        heading: "No automations yet",
                        description: "Automations react to what happens in your home. Create one to get started."
                    ) {
                        Button("Create automation") {}.buttonStyle(.primaryButton)
                    }
                },
                .init("Heading only") {
                    HAEmptyStateView(icon: .databaseOffOutlineIcon, heading: "Nothing recorded")
                },
            ]
        case .sectionTitle:
            [.init("Default") { HASectionTitle("Living room") }]
        case .tip:
            [
                .init("Short") { HATipView("You can drag cards to reorder them.") },
                .init("Wrapping") {
                    HATipView("Long-press a tile to open its more-info dialog, where every attribute is listed.")
                },
            ]
        case .label:
            [
                .init("Untinted") { HALabel("Untinted") },
                .init("With icon") { HALabel("With icon", icon: .homeOutlineIcon) },
                .init("Tinted, light text") { HALabel("Tinted", color: .haPrimary) },
                .init("Tinted, dark text") { HALabel("Tinted", color: .yellow) },
                .init("Dense") { HALabel("Dense", dense: true) },
                .init("Dense with icon") {
                    HALabel("Dense", icon: .homeOutlineIcon, color: .haSuccessColor, dense: true)
                },
            ]
        case .bigNumber:
            [
                .init("Unit on top") { HABigNumber(value: 21.5, unit: "°C") },
                .init("Unit at bottom") { HABigNumber(value: 21.5, unit: "°C", unitPosition: .bottom) },
                .init("No decimals") { HABigNumber(value: 64, unit: "%", fractionLength: 0) },
                .init("Custom size") { HABigNumber(value: 1013.25, unit: "hPa", fractionLength: 2, size: 34) },
                .init("No unit") { HABigNumber(value: 7) },
            ]
        case .treeIndicator:
            [
                .init("Continuing") { HATreeIndicator() },
                .init("Last child") { HATreeIndicator(isEnd: true) },
                .init("Taller row") { HATreeIndicator(height: 72) },
            ]
        case .badge:
            [
                .init("Icon and value") { HABadge("21.5 °C", icon: .thermometerIcon) },
                .init("With label") { HABadge("21.5 °C", icon: .thermometerIcon, label: "Living room") },
                .init("Tinted icon") { HABadge("On", icon: .lightbulbOnIcon, color: .haWarningColor) },
                .init("Icon only") { HABadge(icon: .homeOutlineIcon) },
                .init("Without icon") { HABadge("No icon") },
                .init("As a button") { HABadge("Tap me", icon: .homeOutlineIcon, action: {}) },
            ]
        case .segmentedBar:
            [
                .init("Heading and legend") {
                    HASegmentedBar(
                        segments: DesignSystemComponent.sampleSegments,
                        heading: "Energy sources",
                        description: "21.7 kWh"
                    )
                },
                .init("Bar only") {
                    HASegmentedBar(segments: DesignSystemComponent.sampleSegments, showsLegend: false)
                },
                .init("Segment hidden") {
                    HASegmentedBar(
                        segments: DesignSystemComponent.sampleSegments,
                        hiddenSegmentIDs: ["grid"]
                    )
                },
                .init("No segments") { HASegmentedBar(segments: []) },
            ]
        case .settingsRow:
            [
                .init("Heading only") {
                    HASettingsRow(heading: "Location") {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
                .init("With description") {
                    HASettingsRow(heading: "Background refresh", description: "Keeps sensors up to date.") {
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                },
                .init("With prefix") {
                    HASettingsRow(heading: "Settings", description: "An icon ahead of the heading.") {
                        MaterialDesignIconsImage(icon: .cogIcon, size: 24)
                    } content: {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
                .init("Narrow") {
                    HASettingsRow(heading: "Narrow", description: "The control moves below.", narrow: true) {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
                .init("Slim") {
                    HASettingsRow(heading: "Slim", slim: true) {
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                },
                .init("Three line") {
                    HASettingsRow(
                        heading: "Three line",
                        description: "Room reserved for a description that runs on for three whole lines.",
                        threeLine: true
                    ) {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
            ]
        case .marqueeText:
            [
                .init("Fits, so it stays still") { HAMarqueeText("Short enough to fit") },
                // Held still: its start is the only frame of a scrolling marquee that can be
                // captured the same way twice.
                .init("Overflows, clipped at its start") {
                    HAMarqueeText(
                        "A media title far too long to fit in the space this label has been given",
                        scrolls: false
                    )
                    .frame(width: 200)
                },
            ]
        case .faded:
            [
                .init("Faded") {
                    HAFadedView {
                        Text(String(repeating: "This paragraph is long enough to be cut off and faded. ", count: 8))
                    }
                },
                .init("Short enough to show in full") {
                    HAFadedView { Text("A single short line.") }
                },
            ]
        case .progressRing:
            [
                .init("Sizes") {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        ForEach(HAProgressRing.Size.allCases, id: \.rawValue) { size in
                            HAProgressRing(value: 0.65, size: size)
                        }
                    }
                },
                .init("Empty") { HAProgressRing(value: 0) },
                .init("Full") { HAProgressRing(value: 1) },
                .init("Above maximum, clamped") { HAProgressRing(value: 1.4) },
                .init("Indeterminate") { HAProgressRing() },
            ]
        case .collapsible:
            [
                .init("Collapsed") {
                    CollapsibleView { Text("Header") } expandedContent: { Text("Content") }
                },
                .init("Expanded") {
                    CollapsibleView(startExpanded: true) { Text("Header") } expandedContent: {
                        Text("Content")
                    }
                },
                .init("Outlined") {
                    CollapsibleView(startExpanded: true, outlined: true) { Text("Header") } expandedContent: {
                        Text("Content")
                    }
                },
                .init("Chevron on the leading edge") {
                    CollapsibleView(startExpanded: true, leftChevron: true) { Text("Header") } expandedContent: {
                        Text("Content")
                    }
                },
                .init("Pinned open") {
                    CollapsibleView(noCollapse: true) { Text("Header") } expandedContent: { Text("Content") }
                },
            ]
        case .assistChip:
            [
                .init("Outlined") { HAAssistChip("Outlined") {} },
                .init("With icon") { HAAssistChip("With icon", icon: .homeOutlineIcon) {} },
                .init("Trailing icon") { HAAssistChip("Trailing icon", trailingIcon: .chevronDownIcon) {} },
                .init("Filled") { HAAssistChip("Filled", filled: true) {} },
                .init("Active") { HAAssistChip("Active", icon: .homeOutlineIcon, isActive: true) {} },
            ]
        case .filterChip:
            [
                .init("Unselected") { HAFilterChip("Unselected", isSelected: false) {} },
                .init("Selected") { HAFilterChip("Selected", isSelected: true) {} },
                .init("Selected without check") {
                    HAFilterChip("Selected", isSelected: true, showsLeadingCheck: false) {}
                },
            ]
        case .inputChip:
            [
                .init("Plain") { HAInputChip("Plain") },
                .init("Removable") { HAInputChip("Removable", onRemove: {}) },
                .init("With icon") { HAInputChip("With icon", icon: .homeOutlineIcon, onRemove: {}) },
                .init("Selected") {
                    HAInputChip("Selected", icon: .homeOutlineIcon, isSelected: true, onRemove: {})
                },
            ]
        case .buttonToggleGroup:
            [
                .init("Labels") {
                    HAButtonToggleGroup(
                        buttons: [
                            .init(id: "day", label: "Day"),
                            .init(id: "week", label: "Week"),
                            .init(id: "month", label: "Month"),
                        ],
                        selection: .constant("week")
                    )
                },
                .init("Icons") {
                    HAButtonToggleGroup(
                        buttons: [
                            .init(id: "list", label: "List", icon: .formatListBulletedIcon),
                            .init(id: "grid", label: "Grid", icon: .viewGridIcon),
                        ],
                        selection: .constant("grid")
                    )
                },
                .init("Full width") {
                    HAButtonToggleGroup(
                        buttons: [.init(id: "a", label: "A"), .init(id: "b", label: "B")],
                        selection: .constant("a"),
                        fullWidth: true
                    )
                },
                .init("Disabled") {
                    HAButtonToggleGroup(
                        buttons: [.init(id: "a", label: "A"), .init(id: "b", label: "B")],
                        selection: .constant("a"),
                        isDisabled: true
                    )
                },
            ]
        case .iconButtonToggle:
            [
                .init("Off") {
                    HAIconButtonToggle(icon: .starOutlineIcon, label: "Favourite", isSelected: .constant(false))
                },
                .init("On") {
                    HAIconButtonToggle(icon: .starIcon, label: "Favourite", isSelected: .constant(true))
                },
                .init("On, border only") {
                    HAIconButtonToggle(
                        icon: .starIcon,
                        label: "Favourite",
                        isSelected: .constant(true),
                        borderOnly: true
                    )
                },
            ]
        case .progressButton:
            HAProgressButtonState.allCases.map { state in
                .init(state.rawValue) {
                    HAProgressButton("Send", icon: .sendIcon, state: state) {}
                }
            }
        case .controlSlider:
            HAControlSlider.Mode.allCases.map { mode in
                .init(mode.rawValue.capitalized) {
                    HAControlSlider(value: .constant(60), mode: mode, label: mode.rawValue)
                }
            } + [
                .init("With handle") { HAControlSlider(value: .constant(60), showsHandle: true) },
                .init("Inverted") {
                    HAControlSlider(value: .constant(60), scale: HASliderScale(inverted: true))
                },
                .init("Disabled") { HAControlSlider(value: .constant(60), isDisabled: true) },
                .init("Gradient track") {
                    HAControlSlider(
                        value: .constant(40),
                        mode: .cursor,
                        trackGradient: Gradient(colors: [
                            Color(.sRGB, red: 1, green: 0.60, blue: 0.25, opacity: 1),
                            .white,
                            Color(.sRGB, red: 0.65, green: 0.80, blue: 1, opacity: 1),
                        ])
                    )
                },
                .init("Vertical") {
                    HStack(spacing: DesignSystem.Spaces.three) {
                        HAControlSlider(value: .constant(60), vertical: true)
                        HAControlSlider(value: .constant(60), mode: .end, vertical: true)
                        HAControlSlider(value: .constant(60), mode: .cursor, vertical: true)
                    }
                    .frame(height: 140)
                },
            ]
        case .controlSwitch:
            [
                .init("On") { HAControlSwitch(isOn: .constant(true)) },
                .init("Off") { HAControlSwitch(isOn: .constant(false)) },
                .init("With icons") {
                    HAControlSwitch(
                        isOn: .constant(true),
                        iconOn: .lightbulbOnIcon,
                        iconOff: .lightbulbOutlineIcon
                    )
                },
                .init("Reversed") { HAControlSwitch(isOn: .constant(true), reversed: true) },
                .init("Disabled") { HAControlSwitch(isOn: .constant(true), isDisabled: true) },
                .init("Vertical") {
                    HStack(spacing: DesignSystem.Spaces.three) {
                        HAControlSwitch(isOn: .constant(true), vertical: true)
                        HAControlSwitch(isOn: .constant(false), vertical: true)
                    }
                    .frame(height: 140)
                },
            ]
        case .controlButton:
            [
                .init("Enabled") { HAControlButton(icon: .powerIcon, label: "Toggle") {} },
                .init("Disabled") {
                    HAControlButton(icon: .minusIcon, label: "Decrease", isDisabled: true) {}
                },
            ]
        case .controlButtonGroup:
            [
                .init("Horizontal") {
                    HAControlButtonGroup {
                        HAControlButton(icon: .powerIcon, label: "Toggle") {}
                        HAControlButton(icon: .plusIcon, label: "Increase") {}
                        HAControlButton(icon: .minusIcon, label: "Decrease") {}
                    }
                },
                .init("Vertical") {
                    HAControlButtonGroup(vertical: true) {
                        HAControlButton(icon: .plusIcon, label: "Increase") {}
                        HAControlButton(icon: .minusIcon, label: "Decrease") {}
                    }
                    .frame(height: 100)
                },
            ]
        case .gauge:
            [
                .init("Filled") { HAGauge(value: 64, label: "Humidity") },
                .init("Empty") { HAGauge(value: 0, label: "Empty") },
                .init("Full") { HAGauge(value: 100, label: "Full") },
                .init("Custom value text") {
                    HAGauge(value: 64, label: "Humidity", valueText: "64 %")
                },
                .init("Needle with levels") {
                    HAGauge(
                        value: 72,
                        label: "CPU",
                        levels: [
                            .init(level: 0, color: .haSuccessColor),
                            .init(level: 50, color: .haWarningColor),
                            .init(level: 85, color: .haErrorColor),
                        ]
                    )
                },
            ]
        case .controlSelect:
            [
                .init("Labels") {
                    HAControlSelect(
                        options: [
                            .init(id: "off", label: "Off"),
                            .init(id: "heat", label: "Heat"),
                            .init(id: "cool", label: "Cool"),
                        ],
                        selection: .constant("heat")
                    )
                },
                .init("Icons only") {
                    HAControlSelect(
                        options: [
                            .init(id: "off", label: "Off", icon: .powerIcon),
                            .init(id: "heat", label: "Heat", icon: .fireIcon),
                            .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
                        ],
                        selection: .constant("cool"),
                        hidesOptionLabels: true
                    )
                },
                .init("Disabled option") {
                    HAControlSelect(
                        options: [
                            .init(id: "a", label: "A"),
                            .init(id: "b", label: "B", isDisabled: true),
                        ],
                        selection: .constant("a")
                    )
                },
                .init("Vertical") {
                    HAControlSelect(
                        options: [
                            .init(id: "off", label: "Off", icon: .powerIcon),
                            .init(id: "heat", label: "Heat", icon: .fireIcon),
                        ],
                        selection: .constant("heat"),
                        vertical: true,
                        hidesOptionLabels: true
                    )
                    .frame(height: 120)
                },
            ]
        case .controlNumberButtons:
            [
                .init("With unit") {
                    HAControlNumberButtons(
                        value: .constant(21),
                        scale: HASliderScale(min: 7, max: 35, step: 0.5),
                        unit: "°C",
                        fractionLength: 1
                    )
                },
                .init("Plain") { HAControlNumberButtons(value: .constant(50)) },
                .init("At its minimum") { HAControlNumberButtons(value: .constant(0)) },
                .init("At its maximum") { HAControlNumberButtons(value: .constant(100)) },
                .init("Disabled") { HAControlNumberButtons(value: .constant(50), isDisabled: true) },
            ]
        case .controlCircularSlider:
            [
                .init("Single target") {
                    HAControlCircularSlider(
                        value: .constant(21),
                        scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
                        current: 19
                    )
                },
                .init("Dual target") {
                    HAControlCircularSlider(
                        low: .constant(18),
                        high: .constant(24),
                        scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
                        current: 21
                    )
                },
                .init("Without a current reading") {
                    HAControlCircularSlider(value: .constant(60))
                },
                .init("Disabled") {
                    HAControlCircularSlider(value: .constant(60), isDisabled: true)
                },
            ]
        case .selectBox:
            [
                .init("With descriptions") {
                    HASelectBox(
                        options: [
                            .init(
                                id: "cloud",
                                label: "Home Assistant Cloud",
                                description: "The easiest way to connect from anywhere."
                            ),
                            .init(
                                id: "manual",
                                label: "Manual",
                                description: "Enter the address of your instance yourself."
                            ),
                        ],
                        selection: .constant("cloud")
                    )
                },
                .init("In columns") {
                    HASelectBox(
                        options: [
                            .init(id: "a", label: "One"),
                            .init(id: "b", label: "Two"),
                            .init(id: "c", label: "Three", isDisabled: true),
                        ],
                        selection: .constant("b"),
                        maxColumns: 3
                    )
                },
            ]
        case .haCard:
            [
                .init("Default") { HACard { Text("Card content").padding() } },
                .init("With a header") { HACard(header: "Header") { Text("Card content").padding() } },
                .init("Raised") { HACard(raised: true) { Text("Card content").padding() } },
            ]
        case .tileIcon:
            [
                .init("Default") { HATileIcon(icon: .lightbulbIcon) },
                .init("Tinted") { HATileIcon(icon: .lightbulbOnIcon, color: .haWarningColor) },
                .init("Without a background") {
                    HATileIcon(icon: .lightbulbOnIcon, color: .haWarningColor, showsBackground: false)
                },
                .init("With a badge") {
                    HATileIcon(icon: .thermometerIcon, color: .haPrimary) {
                        HATileBadge(icon: .alertIcon, color: .haErrorColor)
                    }
                },
            ]
        case .tileBadge:
            [
                .init("Default") { HATileBadge(icon: .alertIcon) },
                .init("Error") { HATileBadge(icon: .alertIcon, color: .haErrorColor) },
                .init("Warning") { HATileBadge(icon: .batteryLowIcon, color: .haWarningColor) },
            ]
        case .tileInfo:
            [
                .init("Both lines") { HATileInfo(primary: "Ceiling light", secondary: "On") },
                .init("Primary only") { HATileInfo(primary: "Ceiling light") },
                .init("Secondary loading") { HATileInfo(primary: "Ceiling light", isSecondaryLoading: true) },
                .init("Truncating") {
                    HATileInfo(
                        primary: "A name far too long to fit on one line of a tile",
                        secondary: "And a state that is also much too long"
                    )
                },
                .init("Centred") {
                    HATileInfo(primary: "Centred", secondary: "For a vertical tile", alignment: .center)
                },
            ]
        case .tileCard:
            [
                .init("Inactive") { HATileCard(icon: .lightbulbIcon, primary: "Ceiling light", secondary: "Off") },
                .init("Active") {
                    HATileCard(
                        icon: .lightbulbOnIcon,
                        color: .haWarningColor,
                        primary: "Ceiling light",
                        secondary: "On · 60%",
                        isActive: true
                    )
                },
                .init("With a feature") {
                    HATileCard(
                        icon: .lightbulbOnIcon,
                        color: .haWarningColor,
                        primary: "Ceiling light",
                        secondary: "On · 60%",
                        isActive: true
                    ) {
                        HAControlSlider(value: .constant(60))
                    }
                },
                .init("Vertical") {
                    HATileCard(icon: .lightbulbIcon, primary: "Ceiling", secondary: "Off", vertical: true)
                },
                .init("Vertical, side by side") {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        HATileCard(icon: .lightbulbIcon, primary: "Ceiling", secondary: "Off", vertical: true)
                        HATileCard(
                            icon: .thermometerIcon,
                            color: .haPrimary,
                            primary: "Thermostat",
                            secondary: "21 °C",
                            vertical: true,
                            isActive: true
                        )
                    }
                },
            ]
        case .entityCard:
            [
                .init("With a unit") {
                    HAEntityCard(
                        name: "Living room",
                        icon: .thermometerIcon,
                        color: .haPrimary,
                        value: "21.5",
                        unit: "°C"
                    )
                },
                .init("With a footer") {
                    HAEntityCard(name: "Humidity", value: "64", unit: "%", footer: "Updated 5 minutes ago")
                },
                .init("Textual state") { HAEntityCard(name: "Front door", icon: .doorIcon, value: "Closed") },
            ]
        case .buttonCard:
            [
                .init("Icon and name") { HAButtonCard(name: "Ceiling light", icon: .lightbulbIcon) {} },
                .init("With a state") {
                    HAButtonCard(
                        name: "Ceiling light",
                        icon: .lightbulbOnIcon,
                        color: .haWarningColor,
                        state: "On"
                    ) {}
                },
                .init("Icon only") { HAButtonCard(icon: .powerIcon) {} },
                .init("Name only") { HAButtonCard(name: "No icon") {} },
            ]
        case .glanceCard:
            [
                .init("With a title") {
                    HAGlanceCard(title: "Lights", items: DesignSystemComponent.sampleGlanceItems)
                },
                .init("Two columns") {
                    HAGlanceCard(items: DesignSystemComponent.sampleGlanceItems, columns: 2)
                },
                .init("Without names") {
                    HAGlanceCard(items: DesignSystemComponent.sampleGlanceItems, showsNames: false)
                },
                .init("Without states") {
                    HAGlanceCard(items: DesignSystemComponent.sampleGlanceItems, showsStates: false)
                },
            ]
        case .gaugeCard:
            [
                .init("Filled") { HAGaugeCard(name: "Humidity", value: 64, valueText: "64 %") },
                .init("Needle with levels") {
                    HAGaugeCard(
                        name: "CPU",
                        value: 72,
                        levels: [
                            .init(level: 0, color: .haSuccessColor),
                            .init(level: 50, color: .haWarningColor),
                            .init(level: 85, color: .haErrorColor),
                        ]
                    )
                },
            ]
        case .markdownCard:
            [
                .init("With a title") {
                    HAMarkdownCard(
                        title: "Welcome",
                        content: "The **kitchen** light is on and the _hallway_ is off. Check `sensor.power`."
                    )
                },
                .init("Without a title") { HAMarkdownCard(content: "No title, just a line of prose.") },
                // The card renders block structure, not just inline emphasis — see the Markdown
                // component for the full set.
                .init("With block content") {
                    HAMarkdownCard(
                        title: "Today",
                        content: "## Chores\n\n- [x] Coffee\n- [ ] Water the plants\n\n> Garage still open."
                    )
                },
            ]
        case .headingCard:
            [
                .init("Title") { HAHeadingCard(heading: "Living room", icon: .sofaIcon) },
                .init("Subtitle") { HAHeadingCard(heading: "Upstairs", style: .subtitle) },
                .init("With a badge") {
                    HAHeadingCard(heading: "Kitchen", icon: .silverwareForkKnifeIcon) {
                        HABadge("21.5 °C", icon: .thermometerIcon)
                    }
                },
            ]
        case .clockCard:
            [
                .init("Default") {
                    HAClockCard(date: DesignSystemComponent.sampleDate, timeZone: DesignSystemComponent.sampleTimeZone)
                },
                .init("Large, with a title") {
                    HAClockCard(
                        date: DesignSystemComponent.sampleDate,
                        title: "Home",
                        size: .large,
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("Seconds and date") {
                    HAClockCard(
                        date: DesignSystemComponent.sampleDate,
                        size: .small,
                        showsSeconds: true,
                        showsDate: true,
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("Without a background") {
                    HAClockCard(
                        date: DesignSystemComponent.sampleDate,
                        timeZone: DesignSystemComponent.sampleTimeZone,
                        showsBackground: false
                    )
                },
            ]
        case .thermostatCard:
            [
                .init("Single target") {
                    HAThermostatCard(name: "Living room", target: .constant(21), current: 19, action: "Heating")
                },
                .init("Current as primary") {
                    HAThermostatCard(
                        name: "Living room",
                        target: .constant(21),
                        current: 19,
                        showsCurrentAsPrimary: true
                    )
                },
                .init("Dual target with modes") {
                    HAThermostatCard(
                        name: "Bedroom",
                        low: .constant(18),
                        high: .constant(24),
                        current: 21,
                        action: "Idle"
                    ) {
                        HAControlSelect(
                            options: [
                                .init(id: "off", label: "Off", icon: .powerIcon),
                                .init(id: "heat", label: "Heat", icon: .fireIcon),
                                .init(id: "cool", label: "Cool", icon: .snowflakeIcon),
                            ],
                            selection: .constant("heat"),
                            hidesOptionLabels: true
                        )
                    }
                },
            ]
        case .todoListCard:
            [
                .init("With a title") {
                    HATodoListCard(title: "Shopping", items: DesignSystemComponent.sampleTodoItems)
                },
                .init("Completed hidden") {
                    HATodoListCard(items: DesignSystemComponent.sampleTodoItems, hidesCompleted: true)
                },
            ]
        case .weatherForecastCard:
            [
                .init("With a forecast") {
                    HAWeatherForecastCard(
                        name: "Home",
                        icon: .weatherPartlyCloudyIcon,
                        temperature: "21 °C",
                        condition: "Partly cloudy",
                        attributes: ["1013 hPa", "64 %", "12 km/h"],
                        forecast: DesignSystemComponent.sampleForecast
                    )
                },
                .init("Current only") {
                    HAWeatherForecastCard(name: "Home", icon: .weatherSunnyIcon, temperature: "24 °C")
                },
            ]
        case .pictureCard:
            [
                .init("Plain") { HAPictureCard(image: Image(systemSymbol: .photo)) },
                .init("Captioned") {
                    HAPictureCard(image: Image(systemSymbol: .photo), name: "Front door", state: "Closed")
                },
            ]
        case .alarmPanelCard:
            [
                .init("Disarmed") {
                    HAAlarmPanelCard(
                        name: "Alarm",
                        state: "Disarmed",
                        modes: [.init(id: "home", label: "Home"), .init(id: "away", label: "Away")],
                        onMode: { _ in }
                    )
                },
                .init("Armed, with a keypad") {
                    HAAlarmPanelCard(
                        name: "Alarm",
                        state: "Armed away",
                        stateColor: .haErrorColor,
                        modes: [.init(id: "disarm", label: "Disarm")],
                        code: .constant("123"),
                        showsKeypad: true,
                        onMode: { _ in }
                    )
                },
            ]
        case .tabGroup:
            [
                .init("Wide") { HATabGroup(tabs: DesignSystemComponent.sampleTabs, selection: .constant("areas")) },
                .init("Narrow") {
                    HATabGroup(tabs: DesignSystemComponent.sampleTabs, selection: .constant("areas"), narrow: true)
                },
            ]
        case .iconButtonGroup:
            [
                .init("Default") {
                    HAIconButtonGroup {
                        HAIconButtonToggle(icon: .formatBoldIcon, label: "Bold", isSelected: .constant(true))
                        HAIconButtonToggle(icon: .formatItalicIcon, label: "Italic", isSelected: .constant(false))
                        HAIconButtonToggle(
                            icon: .formatUnderlineIcon,
                            label: "Underline",
                            isSelected: .constant(false)
                        )
                    }
                },
            ]
        case .statisticCard:
            [
                .init("With a unit") {
                    HAStatisticCard(
                        name: "Energy used",
                        icon: .flashIcon,
                        color: .haWarningColor,
                        value: "412",
                        unit: "kWh",
                        period: "This month"
                    )
                },
                .init("Without an icon") {
                    HAStatisticCard(name: "Mean temperature", value: "18.4", unit: "°C", period: "Last 7 days")
                },
            ]
        case .humidifierCard:
            [
                .init("Target as primary") {
                    HAHumidifierCard(name: "Bedroom", target: .constant(55), current: 48, action: "Humidifying")
                },
                .init("Current as primary") {
                    HAHumidifierCard(
                        name: "Study",
                        target: .constant(60),
                        current: 62,
                        showsCurrentAsPrimary: true
                    )
                },
            ]
        case .historyChart:
            [
                .init("One series, filled") {
                    HAHistoryChart(
                        series: [DesignSystemComponent.sampleTemperature],
                        showsArea: true,
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("Several series") {
                    HAHistoryChart(
                        series: [
                            DesignSystemComponent.sampleTemperature,
                            DesignSystemComponent.sampleHumidity,
                        ],
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("Straight interpolation") {
                    HAHistoryChart(
                        series: [DesignSystemComponent.sampleTemperature],
                        isStepped: false,
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
            ]
        case .historyTimeline:
            [
                .init("Default") { HAHistoryTimeline(rows: DesignSystemComponent.sampleTimelineRows) },
            ]
        case .historyGraphCard:
            [
                .init("Chart and timeline") {
                    HAHistoryGraphCard(
                        title: "Living room",
                        series: [DesignSystemComponent.sampleTemperature],
                        timelineRows: DesignSystemComponent.sampleTimelineRows,
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("Chart only") {
                    HAHistoryGraphCard(
                        title: "Temperature",
                        series: [DesignSystemComponent.sampleTemperature],
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
            ]
        case .statisticsChart:
            [
                .init("Stacked sources") {
                    HAStatisticsChart(
                        bars: DesignSystemComponent.sampleStatisticsBars,
                        colors: ["Grid": .haPrimary, "Solar": .haWarningColor],
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
                .init("One source") {
                    HAStatisticsChart(
                        bars: DesignSystemComponent.sampleStatisticsBars.map {
                            HAStatisticsBar(date: $0.date, contributions: Array($0.contributions.prefix(1)))
                        },
                        colors: ["Grid": .haPrimary],
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
            ]
        case .statisticsGraphCard:
            [
                .init("Default") {
                    HAStatisticsGraphCard(
                        title: "Energy",
                        bars: DesignSystemComponent.sampleStatisticsBars,
                        colors: ["Grid": .haPrimary, "Solar": .haWarningColor],
                        timeZone: DesignSystemComponent.sampleTimeZone
                    )
                },
            ]
        case .energyDistributionCard:
            [
                .init("Default") {
                    HAEnergyDistributionCard(
                        title: "Energy distribution",
                        sources: [
                            .init(name: "Solar", icon: .solarPowerIcon, value: "12.4 kWh", color: .haWarningColor),
                            .init(name: "Grid", icon: .transmissionTowerIcon, value: "6.1 kWh", color: .haPrimary),
                            .init(name: "Battery", icon: .batteryIcon, value: "3.2 kWh", color: .haSuccessColor),
                        ],
                        consumption: .init(name: "Home", icon: .homeIcon, value: "21.7 kWh", color: .haPrimary)
                    )
                },
            ]
        case .toast:
            [
                .init("Message only") { HAToast("Settings saved") },
                .init("With an action") { HAToast("Could not reach the server", actionTitle: "Retry") {} },
            ]
        case .progressBar:
            [
                .init("Empty") { HAProgressBar(value: 0) },
                .init("Partial") { HAProgressBar(value: 0.35) },
                .init("Full") { HAProgressBar(value: 1) },
                .init("Above maximum, clamped") { HAProgressBar(value: 1.4) },
                .init("Tinted") { HAProgressBar(value: 0.6, tint: .haSuccessColor) },
            ]
        case .labelBadge:
            [
                .init("Label only") { HALabelBadge(label: "Label") },
                .init("Label and description") { HALabelBadge(label: "Label", description: "Description") },
                .init("Description only") { HALabelBadge(description: "Description", color: .haPrimary) },
                .init("Truncating label") {
                    HALabelBadge(label: "Big label that truncates", description: "Description", color: .haWarningColor)
                },
            ]
        case .hsColorPicker:
            [
                .init("Unsaturated") { HAHSColorPicker(hue: .constant(0), saturation: .constant(0), diameter: 160) },
                .init("Warm") { HAHSColorPicker(hue: .constant(30), saturation: .constant(0.9), diameter: 160) },
                .init("Cool") { HAHSColorPicker(hue: .constant(210), saturation: .constant(0.6), diameter: 160) },
                .init("Disabled") {
                    HAHSColorPicker(hue: .constant(120), saturation: .constant(0.8), diameter: 160, isDisabled: true)
                },
            ]
        case .formField:
            [
                .init("Label and control") {
                    HAFormField(label: "Enable notifications") {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
                .init("With helper text") {
                    HAFormField(label: "Track location", helperText: "Used for zone automations.") {
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                },
                .init("Error") {
                    HAFormField(label: "Server address", helperText: "Not a valid URL.", isError: true) {
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                },
                .init("Trailing control") {
                    HAFormField(label: "Trailing control", controlLeading: false) {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
            ]
        case .headingBadge:
            [
                .init("With icon") { HAHeadingBadge("21.5 °C", icon: .thermometerIcon) },
                .init("Tinted icon") { HAHeadingBadge("64 %", icon: .waterPercentIcon, color: .haPrimary) },
                .init("Text only") { HAHeadingBadge("3 lights on") },
                .init("As a button") { HAHeadingBadge("Tap me", icon: .homeOutlineIcon, action: {}) },
            ]
        case .dialogHeader:
            [
                .init("Title") { HADialogHeader(title: "Settings", onClose: {}) },
                .init("With a subtitle") {
                    HADialogHeader(title: "Ceiling light", subtitle: "Living room", onClose: {})
                },
                .init("With an action") {
                    HADialogHeader(title: "With an action", onClose: {}) {
                        Button("Save") {}.buttonStyle(.textButton)
                    }
                },
                .init("Without a close button") { HADialogHeader(title: "No close button") },
            ]
        case .relativeTime:
            [
                .init("A minute ago") {
                    HARelativeTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-60),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("An hour ago") {
                    HARelativeTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-3600),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("Days ago") {
                    HARelativeTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-86400 * 3),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("In the future") {
                    HARelativeTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(3600),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("Short") {
                    HARelativeTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-3600),
                        now: DesignSystemComponent.sampleDate,
                        style: .short
                    )
                },
            ]
        case .sankeyChart:
            [
                .init("Two sources into one") {
                    HASankeyChart(
                        nodes: DesignSystemComponent.sampleSankeyNodes,
                        links: DesignSystemComponent.sampleSankeyLinks
                    )
                },
                .init("Split across three columns") {
                    HASankeyChart(
                        nodes: DesignSystemComponent.sampleSankeyNodes + [
                            HASankeyNode(id: "lights", value: 8, column: 2, label: "Lights", color: .haWarningColor),
                            HASankeyNode(id: "other", value: 10.5, column: 2, label: "Other", color: .haDisabled),
                        ],
                        links: DesignSystemComponent.sampleSankeyLinks + [
                            HASankeyLink(source: "home", target: "lights", value: 8),
                            HASankeyLink(source: "home", target: "other", value: 10.5),
                        ]
                    )
                },
                .init("Without labels") {
                    HASankeyChart(
                        nodes: DesignSystemComponent.sampleSankeyNodes,
                        links: DesignSystemComponent.sampleSankeyLinks,
                        showsLabels: false
                    )
                },
            ]
        case .sunburstChart:
            [
                .init("Nested breakdown") {
                    HASunburstChart(segments: DesignSystemComponent.sampleSunburst, diameter: 180)
                },
                .init("One level") {
                    HASunburstChart(
                        segments: DesignSystemComponent.sampleSunburst.map {
                            HASunburstSegment(id: $0.id, name: $0.name, value: $0.value, color: $0.color)
                        },
                        diameter: 180
                    )
                },
                .init("Without labels") {
                    HASunburstChart(
                        segments: DesignSystemComponent.sampleSunburst,
                        diameter: 180,
                        showsLabels: false
                    )
                },
            ]
        case .energySourcesTable:
            [
                .init("With costs") {
                    HAEnergySourcesTable(
                        title: "Sources",
                        groups: DesignSystemComponent.sampleEnergyGroups,
                        totalEnergy: "19.2 kWh",
                        totalCost: "£1.47"
                    )
                },
                .init("Totals only") {
                    HAEnergySourcesTable(
                        groups: DesignSystemComponent.sampleEnergyGroups,
                        totalEnergy: "19.2 kWh",
                        totalCost: "£1.47",
                        showsOnlyTotals: true
                    )
                },
                .init("Without costs") {
                    HAEnergySourcesTable(
                        groups: [DesignSystemComponent.sampleEnergyGroups[0]],
                        totalEnergy: "15.5 kWh"
                    )
                },
            ]
        case .energyPeriodSelector:
            [
                .init("Month") {
                    HAEnergyPeriodSelector(
                        label: "August 2026",
                        periods: DesignSystemComponent.samplePeriods,
                        period: .constant("month")
                    )
                },
                .init("Comparing") {
                    HAEnergyPeriodSelector(
                        label: "29 August 2026",
                        periods: DesignSystemComponent.samplePeriods,
                        period: .constant("day"),
                        isComparing: .constant(true)
                    )
                },
                .init("Without comparison") {
                    HAEnergyPeriodSelector(
                        label: "2026",
                        periods: DesignSystemComponent.samplePeriods,
                        period: .constant("year"),
                        allowsCompare: false
                    )
                },
            ]
        case .entityRow:
            [
                .init("Textual state") {
                    HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
                },
                .init("With a toggle") {
                    HAEntityRow(name: "Bed Light", icon: .lightbulbIcon, color: .haWarningColor) {
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                },
                .init("With an action") {
                    HAEntityRow(
                        name: "Kitchen Lock",
                        icon: .lockIcon,
                        color: .haSuccessColor,
                        actionTitle: "Unlock"
                    ) {}
                },
                .init("With a secondary line") {
                    HAEntityRow(
                        name: "Ecobee",
                        icon: .thermostatIcon,
                        secondary: "Currently: 23 °C",
                        state: "Idle"
                    )
                },
                .init("With cover controls") {
                    HAEntityRow(name: "Kitchen Window", icon: .windowShutterIcon) {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            MaterialDesignIconsImage(icon: .arrowUpIcon, size: 20)
                            MaterialDesignIconsImage(icon: .stopIcon, size: 20)
                            MaterialDesignIconsImage(icon: .arrowDownIcon, size: 20)
                        }
                    }
                },
                .init("Without an icon") { HAEntityRow(name: "No icon", state: "On") },
            ]
        case .entitiesCard:
            [
                .init("With a title") {
                    HAEntitiesCard(title: "Living room") {
                        HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
                        HAEntityRow(name: "Humidity", icon: .waterPercentIcon, state: "23.2 %")
                        HAEntityRow(name: "Bed Light", icon: .lightbulbIcon, color: .haWarningColor) {
                            Toggle("", isOn: .constant(true)).labelsHidden()
                        }
                    }
                },
                .init("With a header toggle") {
                    HAEntitiesCard(title: "Random group", headerToggle: .constant(true)) {
                        HAEntityRow(name: "Romantic Scene", icon: .paletteIcon, actionTitle: "Activate") {}
                        HAEntityRow(name: "Paulus", icon: .accountIcon, color: .haSuccessColor, state: "Home")
                    }
                },
                .init("Without a title") {
                    HAEntitiesCard {
                        HAEntityRow(name: "No title", icon: .homeOutlineIcon, state: "On")
                    }
                },
            ]
        case .lightCard:
            [
                .init("On") { HALightCard(name: "Bed Light", onMore: {}) },
                .init("Dimmed") {
                    HALightCard(name: "Dining Room", color: .haWarningColor.opacity(0.6), onMore: {})
                },
                .init("Unavailable") {
                    HALightCard(name: "Lost Light", color: .haDisabled, secondary: "Unavailable", onMore: {})
                },
                .init("Without an overflow button") { HALightCard(name: "Bed Light") },
            ]
        case .pictureGlanceCard:
            [
                .init("Default") {
                    HAPictureGlanceCard(
                        image: Image(systemSymbol: .photo),
                        title: "Front garden",
                        items: [
                            HAGlanceItem(id: "1", name: "Porch light", icon: .lightbulbOnIcon, state: "On"),
                            HAGlanceItem(id: "2", name: "Front door", icon: .doorIcon, state: "Closed"),
                            HAGlanceItem(id: "3", name: "Garage", icon: .garageIcon, state: "Closed"),
                        ]
                    )
                },
            ]
        case .baseTimeInput:
            [
                .init("Hours and minutes") {
                    HABaseTimeInput(value: .constant(HATimeComponents(hours: 14, minutes: 30)))
                },
                .init("Labelled") {
                    HABaseTimeInput(value: .constant(HATimeComponents(hours: 8, minutes: 5)), label: "Start")
                },
                .init("Required, with helper text") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(hours: 8, minutes: 5)),
                        label: "Start",
                        helper: "When the schedule begins",
                        required: true
                    )
                },
                .init("With seconds") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(hours: 1, minutes: 2, seconds: 3)),
                        enableSecond: true
                    )
                },
                .init("Days through milliseconds") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(
                            days: 2,
                            hours: 3,
                            minutes: 4,
                            seconds: 5,
                            milliseconds: 250
                        )),
                        enableDay: true,
                        enableSecond: true,
                        enableMillisecond: true,
                        noHoursLimit: true
                    )
                },
                .init("12-hour clock") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(hours: 7, minutes: 45, period: .pm)),
                        format: .twelve
                    )
                },
                .init("Clearable") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(hours: 9, minutes: 0)),
                        clearable: true
                    )
                },
                .init("Disabled") {
                    HABaseTimeInput(
                        value: .constant(HATimeComponents(hours: 9, minutes: 0)),
                        label: "Start",
                        disabled: true
                    )
                },
            ]
        case .timeInput:
            [
                .init("Time of day") {
                    HATimeInput(
                        value: .constant(HATimeComponents(hours: 6, minutes: 30)),
                        label: "Wake up",
                        format: .twentyFour
                    )
                },
                .init("With seconds") {
                    HATimeInput(
                        value: .constant(HATimeComponents(hours: 22, minutes: 45, seconds: 30)),
                        enableSecond: true,
                        format: .twentyFour
                    )
                },
                .init("12-hour clock") {
                    HATimeInput(
                        value: .constant(HATimeComponents(hours: 7, minutes: 15, period: .pm)),
                        format: .twelve
                    )
                },
                .init("Required") {
                    HATimeInput(
                        value: .constant(HATimeComponents(hours: 12, minutes: 0)),
                        label: "Trigger at",
                        required: true,
                        format: .twentyFour
                    )
                },
                .init("Disabled") {
                    HATimeInput(
                        value: .constant(HATimeComponents(hours: 12, minutes: 0)),
                        label: "Trigger at",
                        disabled: true,
                        format: .twentyFour
                    )
                },
            ]
        case .durationInput:
            [
                .init("Minutes") {
                    HADurationInput(value: .constant(HATimeComponents(minutes: 5)), label: "Wait")
                },
                .init("Hours, minutes and seconds") {
                    HADurationInput(value: .constant(HATimeComponents(hours: 1, minutes: 30, seconds: 15)))
                },
                .init("With days") {
                    HADurationInput(
                        value: .constant(HATimeComponents(days: 1, hours: 2, minutes: 30, seconds: 15)),
                        enableDay: true
                    )
                },
                .init("With milliseconds") {
                    HADurationInput(
                        value: .constant(HATimeComponents(minutes: 0, seconds: 2, milliseconds: 500)),
                        enableMillisecond: true
                    )
                },
                .init("Negative offset") {
                    HADurationInput(
                        value: .constant(HATimeComponents(minutes: 30)),
                        isNegative: .constant(true),
                        label: "Offset",
                        allowNegative: true
                    )
                },
                .init("Disabled") {
                    HADurationInput(
                        value: .constant(HATimeComponents(minutes: 5)),
                        label: "Wait",
                        disabled: true
                    )
                },
            ]
        case .dateInput:
            [
                .init("A date") {
                    HADateInput(value: .constant(DesignSystemComponent.sampleDate), label: "Start date")
                },
                .init("Empty") {
                    HADateInput(value: .constant(nil), label: "End date")
                },
                .init("With helper text") {
                    HADateInput(
                        value: .constant(DesignSystemComponent.sampleDate),
                        label: "Start date",
                        helper: "Statistics are shown from this day"
                    )
                },
                .init("Required") {
                    HADateInput(
                        value: .constant(DesignSystemComponent.sampleDate),
                        label: "Start date",
                        required: true
                    )
                },
                .init("Clearable") {
                    HADateInput(
                        value: .constant(DesignSystemComponent.sampleDate),
                        label: "Start date",
                        canClear: true
                    )
                },
                .init("Disabled") {
                    HADateInput(
                        value: .constant(DesignSystemComponent.sampleDate),
                        label: "Start date",
                        disabled: true
                    )
                },
            ]
        case .absoluteTime:
            [
                .init("Earlier today — time only") {
                    HAAbsoluteTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-3600),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("Earlier this year — day and month") {
                    HAAbsoluteTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-86400 * 3),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("Another year — with the year") {
                    HAAbsoluteTime(
                        date: DesignSystemComponent.sampleDate.addingTimeInterval(-86400 * 400),
                        now: DesignSystemComponent.sampleDate
                    )
                },
                .init("No timestamp") {
                    HAAbsoluteTime(date: nil, now: DesignSystemComponent.sampleDate)
                },
            ]
        case .markdownText:
            [
                // All six levels: the frontend keeps shrinking to h6, so each has to be tellable
                // from the one above it.
                .init("Headings") {
                    HAMarkdownText("# Level 1\n## Level 2\n### Level 3\n#### Level 4\n##### Level 5\n###### Level 6")
                },
                .init("Inline emphasis, code and links") {
                    HAMarkdownText("The **kitchen** light is _on_. Check `sensor.power`.")
                },
                .init("Bulleted and numbered lists") {
                    HAMarkdownText("- Coffee\n- Toast\n  - Butter\n\n1. Unlock\n2. Disarm")
                },
                .init("Task list") {
                    HAMarkdownText("- [x] Water the plants\n- [ ] Feed the cat")
                },
                .init("Block quote") {
                    HAMarkdownText("> The garage has been open for 2 hours.")
                },
                .init("Fenced code") {
                    HAMarkdownText("```yaml\ntrigger:\n  platform: state\n```")
                },
                .init("Table") {
                    HAMarkdownText("| Room | State |\n| --- | --- |\n| Kitchen | On |\n| Hall | Off |")
                },
                .init("Thematic break") {
                    HAMarkdownText("Above\n\n---\n\nBelow")
                },
            ]
        case .qrCode:
            [
                .init("A link") { HAQRCode(data: "https://www.home-assistant.io") },
                .init("High error correction") {
                    HAQRCode(data: "https://www.home-assistant.io", errorCorrectionLevel: .high)
                },
                .init("Smaller scale, no quiet zone") {
                    HAQRCode(data: "https://www.home-assistant.io", scale: 3, margin: 0)
                },
                .init("Tinted") {
                    HAQRCode(data: "https://www.home-assistant.io", scale: 3, foreground: .haPrimary)
                },
                // White on white would be unscannable, so the foreground is redrawn — the frontend
                // makes the same substitution below a 3:1 ratio.
                .init("Foreground too close to the background") {
                    HAQRCode(
                        data: "https://www.home-assistant.io",
                        scale: 3,
                        foreground: .white,
                        background: .white
                    )
                },
                .init("Nothing to encode") { HAQRCode(data: "") },
            ]
        case .qrScanner:
            [
                .init("Starting the camera") {
                    HAQRScanner(
                        status: .loading,
                        title: "Scan the code",
                        description: "Point the camera at the QR code on the device.",
                        onScan: { _ in }
                    )
                },
                .init("Scan failed, with retry") {
                    HAQRScanner(
                        status: .failed("That code was not recognised."),
                        onScan: { _ in },
                        onRetry: {}
                    )
                },
                .init("Failed with no retry offered") {
                    HAQRScanner(status: .failed("The camera is in use by another app."), onScan: { _ in })
                },
                .init("No camera — type it instead") {
                    HAQRScanner(status: .unavailable("This device has no camera."), onScan: { _ in })
                },
            ]
        case .sparkline:
            [
                .init("A rising trend") { HASparkline(values: DesignSystemComponent.sampleTrend) },
                .init("Without the fill") {
                    HASparkline(values: DesignSystemComponent.sampleTrend, showsFill: false)
                },
                .init("Tinted") {
                    HASparkline(values: DesignSystemComponent.sampleTrend, color: .haSuccessColor)
                },
                // No range to scale against; the line sits at the centre rather than dividing by zero.
                .init("Every reading the same") { HASparkline(values: [7, 7, 7, 7, 7]) },
                .init("Two readings") { HASparkline(values: [2, 9]) },
                .init("Taller") { HASparkline(values: DesignSystemComponent.sampleTrend, height: 100) },
            ]
        case .analogClock:
            [
                .init("Hour ticks") { HAAnalogClock(date: DesignSystemComponent.sampleClockTime) },
                .init("Quarter ticks") {
                    HAAnalogClock(date: DesignSystemComponent.sampleClockTime, diameter: 140, ticks: .quarter)
                },
                .init("Minute ticks, with a second hand") {
                    HAAnalogClock(
                        date: DesignSystemComponent.sampleClockTime,
                        diameter: 140,
                        ticks: .minute,
                        showsSeconds: true
                    )
                },
                .init("No ticks") {
                    HAAnalogClock(date: DesignSystemComponent.sampleClockTime, diameter: 140, ticks: .none)
                },
                .init("Arabic numerals") {
                    HAAnalogClock(
                        date: DesignSystemComponent.sampleClockTime,
                        diameter: 160,
                        ticks: .quarter,
                        numerals: .arabic
                    )
                },
                .init("Roman numerals") {
                    HAAnalogClock(
                        date: DesignSystemComponent.sampleClockTime,
                        diameter: 160,
                        ticks: .none,
                        numerals: .roman
                    )
                },
            ]
        case .errorCard:
            [
                .init("Error") { HAErrorCard(title: "Configuration error") },
                .init("Error with detail") {
                    HAErrorCard(
                        title: "Configuration error",
                        message: "Entity not found: sensor.kitchen_temperature"
                    )
                },
                .init("Warning") {
                    HAErrorCard(title: "Configuration warning", severity: .warning)
                },
            ]
        case .sensorCard:
            [
                .init("With history") {
                    HASensorCard(
                        name: "Kitchen temperature",
                        icon: .thermometerIcon,
                        value: "21.4",
                        unit: "°C",
                        history: DesignSystemComponent.sampleTrend
                    )
                },
                .init("Without history") {
                    HASensorCard(name: "Humidity", icon: .waterPercentIcon, value: "54", unit: "%")
                },
                .init("Tinted, no unit") {
                    HASensorCard(
                        name: "Air quality",
                        icon: .weatherWindyIcon,
                        color: .haSuccessColor,
                        value: "Good",
                        history: DesignSystemComponent.sampleTrend
                    )
                },
            ]
        case .logbookCard:
            [
                .init("Recent activity") {
                    HALogbookCard(title: "Logbook", entries: DesignSystemComponent.sampleLogbook)
                },
                .init("Without a title") {
                    HALogbookCard(entries: Array(DesignSystemComponent.sampleLogbook.prefix(2)))
                },
                .init("Nothing to report") {
                    HALogbookCard(
                        title: "Logbook",
                        entries: [],
                        emptyMessage: "No logbook entries found."
                    )
                },
            ]
        case .mediaControlCard:
            [
                .init("Playing") {
                    HAMediaControlCard(
                        name: "Living room",
                        title: "Speak to Me",
                        subtitle: "Pink Floyd",
                        isPlaying: true,
                        progress: 0.35,
                        onPlayPause: {},
                        onPrevious: {},
                        onNext: {},
                        onMore: {}
                    )
                },
                .init("Paused, no progress known") {
                    HAMediaControlCard(
                        name: "Study",
                        title: "BBC Radio 6 Music",
                        subtitle: "Live",
                        accent: .haSuccessColor,
                        onPlayPause: {},
                        onMore: {}
                    )
                },
                // A pale block takes dark text, which is the contrast rule doing its job rather
                // than a hardcoded white.
                .init("Pale artwork colour") {
                    HAMediaControlCard(
                        name: "Kitchen",
                        title: "I Wanna Be A Hippy",
                        subtitle: "Technohead",
                        accent: .yellow,
                        progress: 0.1,
                        onPlayPause: {},
                        onPrevious: {},
                        onNext: {}
                    )
                },
                .init("Idle") { HAMediaControlCard(name: "Kitchen speaker", accent: .haDisabled) },
                .init("With artwork") {
                    HAMediaControlCard(
                        name: "Living room",
                        title: "Speak to Me",
                        subtitle: "Pink Floyd",
                        artwork: Image(systemSymbol: .musicNote),
                        isPlaying: true,
                        progress: 0.6,
                        onPlayPause: {},
                        onPrevious: {},
                        onNext: {}
                    )
                },
            ]
        case .plantStatusCard:
            [
                .init("With a problem") {
                    HAPlantStatusCard(
                        name: "Monstera",
                        attributes: [
                            .init(
                                id: "moisture",
                                icon: .waterPercentIcon,
                                value: "18",
                                unit: "%",
                                isProblem: true
                            ),
                            .init(id: "temperature", icon: .thermometerIcon, value: "21.4", unit: "°C"),
                            .init(id: "battery", icon: .batteryIcon, value: "88", unit: "%"),
                        ]
                    )
                },
                .init("All well") {
                    HAPlantStatusCard(
                        name: "Fiddle-leaf fig",
                        attributes: [
                            .init(id: "moisture", icon: .waterPercentIcon, value: "42", unit: "%"),
                            .init(id: "temperature", icon: .thermometerIcon, value: "22.1", unit: "°C"),
                        ]
                    )
                },
                .init("With a picture") {
                    HAPlantStatusCard(
                        name: "Monstera",
                        picture: Image(systemSymbol: .leafFill),
                        attributes: [
                            .init(id: "moisture", icon: .waterPercentIcon, value: "42", unit: "%"),
                        ]
                    )
                },
            ]
        case .calendarCard:
            [
                .init("A month with events") {
                    HACalendarCard(
                        title: "Calendar",
                        month: DesignSystemComponent.sampleDate,
                        selectedDay: DesignSystemComponent.sampleDate,
                        events: DesignSystemComponent.sampleCalendarEvents
                    )
                },
                .init("Nothing on the selected day") {
                    HACalendarCard(
                        month: DesignSystemComponent.sampleDate,
                        selectedDay: DesignSystemComponent.sampleDate.addingTimeInterval(86400 * 2),
                        events: DesignSystemComponent.sampleCalendarEvents
                    )
                },
            ]
        case .areaCard:
            [
                .init("With controls and an alert") {
                    HAAreaCard(
                        name: "Living room",
                        icon: .sofaIcon,
                        sensors: ["21.4 °C", "54 %"],
                        alerts: [.init(id: "1", icon: .doorOpenIcon, text: "1")],
                        controls: [
                            .init(
                                id: "light",
                                icon: .lightbulbIcon,
                                label: "Lights",
                                isActive: true,
                                action: {}
                            ),
                            .init(id: "fan", icon: .fanIcon, label: "Fan", isActive: false, action: {}),
                        ]
                    )
                },
                .init("Name and icon only") { HAAreaCard(name: "Hallway", icon: .stairsIcon) },
                // A filled symbol, not an outline: scaled to fill, an outline shows only its empty
                // middle and the variant reads as broken rather than as "this card has a picture".
                .init("With a picture") {
                    HAAreaCard(
                        name: "Kitchen",
                        picture: Image(systemSymbol: .photoFill),
                        sensors: ["2 lights on"]
                    )
                },
            ]
        case .distributionCard:
            [
                .init("A split with its legend") {
                    HADistributionCard(
                        title: "Energy sources",
                        segments: DesignSystemComponent.sampleDistribution
                    )
                },
                // A hidden source leaves the total, so the remaining slices grow to fill the bar.
                .init("One source excluded") {
                    HADistributionCard(
                        title: "Energy sources",
                        segments: DesignSystemComponent.sampleDistribution,
                        hiddenSegmentIDs: ["grid"],
                        onLegendTap: { _ in }
                    )
                },
                .init("Legend collapsed") {
                    HADistributionCard(
                        title: "Devices",
                        segments: DesignSystemComponent.sampleDistributionLong,
                        onToggleExpanded: {}
                    )
                },
                .init("Legend expanded") {
                    HADistributionCard(
                        title: "Devices",
                        segments: DesignSystemComponent.sampleDistributionLong,
                        isExpanded: true,
                        onToggleExpanded: {}
                    )
                },
                .init("Nothing recorded yet") {
                    HADistributionCard(
                        title: "Energy sources",
                        segments: [],
                        emptyMessage: "No data has been recorded yet."
                    )
                },
            ]
        case .assistVoiceOrb:
            // The orb animates, so every variant pins its timeline — otherwise the recorded image
            // would depend on when the snapshot happened to be taken.
            [0, 0.5, 1].map { level in
                .init(level == 0 ? "Silent" : level == 0.5 ? "Half level" : "Full level") {
                    AssistVoiceOrbView(level: level, accessibilityLabel: "Listening")
                        .environment(\.assistOrbFixedTime, DesignSystemComponent.orbFixedTime)
                }
            }
        }
    }

    /// Hourly readings from 2026-08-29 00:00 UTC, pinned so the charts draw the same way each run.
    private static let sampleChartStart = Date(timeIntervalSince1970: 1_787_961_600)

    private static func samplePoints(_ values: [Double]) -> [HAChartSeries.Point] {
        values.enumerated().map { index, value in
            .init(date: sampleChartStart.addingTimeInterval(Double(index) * 3600), value: value)
        }
    }

    private static let sampleTemperature = HAChartSeries(
        id: "t",
        name: "Temperature",
        points: samplePoints([18, 18.5, 19.4, 21, 22.3, 21.6, 20.1])
    )

    private static let sampleHumidity = HAChartSeries(
        id: "h",
        name: "Humidity",
        color: .haSuccessColor,
        points: samplePoints([61, 60, 58, 55, 54, 56, 59])
    )

    private static let sampleTimelineRows: [HAHistoryTimeline.Row] = [
        .init(id: "door", name: "Front door", segments: [
            sampleSegment(0, 6, "Closed", .haDisabled),
            sampleSegment(6, 7, "Open", .haWarningColor),
            sampleSegment(7, 12, "Closed", .haDisabled),
        ]),
        .init(id: "light", name: "Porch light", segments: [
            sampleSegment(0, 5, "Off", .haDisabled),
            sampleSegment(5, 9, "On", .haSuccessColor),
            sampleSegment(9, 12, "Off", .haDisabled),
        ]),
    ]

    private static func sampleSegment(
        _ startHour: Double,
        _ endHour: Double,
        _ label: String,
        _ color: Color
    ) -> HATimelineSegment {
        HATimelineSegment(
            start: sampleChartStart.addingTimeInterval(startHour * 3600),
            end: sampleChartStart.addingTimeInterval(endHour * 3600),
            label: label,
            color: color
        )
    }

    /// Shared by the energy table's variants.
    private static let sampleEnergyGroups = [
        HAEnergySourceGroup(
            id: "solar",
            title: "Solar total",
            rows: [
                .init(id: "roof", name: "Roof array", color: .haWarningColor, energy: "12.4 kWh"),
                .init(id: "shed", name: "Shed array", color: .haWarningColor.opacity(0.6), energy: "3.1 kWh"),
            ],
            totalEnergy: "15.5 kWh"
        ),
        HAEnergySourceGroup(
            id: "grid",
            title: "Grid total",
            rows: [
                .init(id: "import", name: "Grid import", color: .haPrimary, energy: "6.1 kWh", cost: "£1.83"),
                .init(id: "export", name: "Grid export", color: .haSuccessColor, energy: "-2.4 kWh", cost: "-£0.36"),
            ],
            totalEnergy: "3.7 kWh",
            totalCost: "£1.47"
        ),
    ]

    /// Shared by the energy period selector's variants.
    private static let samplePeriods = [
        HAToggleButton(id: "day", label: "Day"),
        HAToggleButton(id: "week", label: "Week"),
        HAToggleButton(id: "month", label: "Month"),
        HAToggleButton(id: "year", label: "Year"),
    ]

    /// Shared by the sunburst chart's variants.
    private static let sampleSunburst = [
        HASunburstSegment(id: "heating", name: "Heating", value: 40, color: .haWarningColor, children: [
            HASunburstSegment(id: "living", name: "Living room", value: 25, color: .haWarningColor.opacity(0.7)),
            HASunburstSegment(id: "bedroom", name: "Bedroom", value: 15, color: .haWarningColor.opacity(0.4)),
        ]),
        HASunburstSegment(id: "appliances", name: "Appliances", value: 35, color: .haPrimary, children: [
            HASunburstSegment(id: "washer", name: "Washer", value: 20, color: .haPrimary.opacity(0.7)),
            HASunburstSegment(id: "oven", name: "Oven", value: 15, color: .haPrimary.opacity(0.4)),
        ]),
        HASunburstSegment(id: "lighting", name: "Lighting", value: 25, color: .haSuccessColor),
    ]

    /// Shared by the sankey chart's variants.
    private static let sampleSankeyNodes = [
        HASankeyNode(id: "solar", value: 12.4, column: 0, label: "Solar", color: .haWarningColor),
        HASankeyNode(id: "grid", value: 6.1, column: 0, label: "Grid", color: .haPrimary),
        HASankeyNode(id: "home", value: 18.5, column: 1, label: "Home", color: .haSuccessColor),
    ]

    private static let sampleSankeyLinks = [
        HASankeyLink(source: "solar", target: "home"),
        HASankeyLink(source: "grid", target: "home"),
    ]

    /// Shared by the statistics chart's variants.
    private static let sampleStatisticsBars: [HAStatisticsBar] = (0 ..< 5).map { day in
        HAStatisticsBar(
            date: sampleChartStart.addingTimeInterval(Double(day) * 86400),
            contributions: [
                .init(name: "Grid", value: Double(8 + day)),
                .init(name: "Solar", value: Double(12 - day)),
            ]
        )
    }

    /// Shared by the tab group's variants.
    private static let sampleTabs = [
        HATabItem(id: "general", name: "General", icon: .cogIcon),
        HATabItem(id: "areas", name: "Areas", icon: .sofaIcon),
        HATabItem(id: "devices", name: "Devices", icon: .devicesIcon),
    ]

    /// Shared by the to-do card's variants.
    private static let sampleTodoItems = [
        HATodoItem(id: "1", summary: "Buy milk", dueDate: Date(timeIntervalSince1970: 1_788_220_800)),
        HATodoItem(id: "2", summary: "Change the filter", description: "Under the sink"),
        HATodoItem(id: "3", summary: "Water the plants", isCompleted: true),
    ]

    /// Shared by the weather card's variants.
    private static let sampleForecast = [
        HAWeatherForecastEntry(id: "1", label: "Mon", icon: .weatherSunnyIcon, high: "24°", low: "14°"),
        HAWeatherForecastEntry(id: "2", label: "Tue", icon: .weatherPartlyCloudyIcon, high: "22°", low: "13°"),
        HAWeatherForecastEntry(id: "3", label: "Wed", icon: .weatherRainyIcon, high: "18°", low: "12°"),
        HAWeatherForecastEntry(id: "4", label: "Thu", icon: .weatherCloudyIcon, high: "19°", low: "11°"),
    ]

    /// Shared by the glance card's variants so they differ only in the option being demonstrated.
    private static let sampleGlanceItems = [
        HAGlanceItem(id: "1", name: "Kitchen", icon: .lightbulbOnIcon, color: .haWarningColor, state: "On"),
        HAGlanceItem(id: "2", name: "Hallway", icon: .lightbulbIcon, state: "Off"),
        HAGlanceItem(id: "3", name: "Porch", icon: .lightbulbIcon, state: "Off"),
        HAGlanceItem(id: "4", name: "Garage", icon: .garageIcon, state: "Closed"),
    ]

    /// 2026-08-29 09:41:07 UTC, pinned so the clock records the same time on every run.
    private static let sampleDate = Date(timeIntervalSince1970: 1_787_996_467)

    /// 2026-08-29 10:09:37 UTC — a time whose three hands sit at clearly different angles, so a
    /// wrongly-driven hand is visible in the recording rather than hiding behind another.
    private static let sampleClockTime = Date(timeIntervalSince1970: 1_787_998_177)

    private static let sampleTrend: [Double] = [18, 18.5, 19.4, 21, 22.3, 21.6, 20.1, 21.4]

    /// The point on the Assist orb's animation timeline the gallery freezes it at, matching
    /// `AssistVoiceOrbViewSnapshot`.
    private static let orbFixedTime: TimeInterval = 100

    private static let sampleDistribution: [HABarSegment] = [
        .init(id: "solar", value: 12.4, color: .haWarningColor, label: "Solar", formattedValue: "12.4 kWh"),
        .init(id: "grid", value: 8.1, color: .haPrimary, label: "Grid", formattedValue: "8.1 kWh"),
        .init(
            id: "battery",
            value: 3.2,
            color: .haSuccessColor,
            label: "Battery",
            formattedValue: "3.2 kWh"
        ),
    ]

    /// More sources than the legend shows folded up, so the collapse is actually exercised.
    private static let sampleDistributionLong: [HABarSegment] = [
        .init(id: "1", value: 4.2, color: .haWarningColor, label: "Heat pump", formattedValue: "4.2 kWh"),
        .init(id: "2", value: 3.1, color: .haPrimary, label: "Car charger", formattedValue: "3.1 kWh"),
        .init(id: "3", value: 2.4, color: .haSuccessColor, label: "Oven", formattedValue: "2.4 kWh"),
        .init(id: "4", value: 1.8, color: .haErrorColor, label: "Dishwasher", formattedValue: "1.8 kWh"),
        .init(id: "5", value: 1.2, color: .haInfoColor, label: "Washing machine", formattedValue: "1.2 kWh"),
        .init(id: "6", value: 0.9, color: .haDisabled, label: "Fridge", formattedValue: "0.9 kWh"),
        .init(id: "7", value: 0.4, color: .haNeutralQuietFill, label: "Router", formattedValue: "0.4 kWh"),
    ]

    private static let sampleCalendarEvents: [HACalendarCardEvent] = [
        .init(id: "1", title: "Bin day", start: sampleDate, end: sampleDate, isAllDay: true),
        .init(
            id: "2",
            title: "Dentist",
            start: sampleDate.addingTimeInterval(3600),
            end: sampleDate.addingTimeInterval(5400),
            color: .haSuccessColor
        ),
        .init(
            id: "3",
            title: "Standup",
            start: sampleDate.addingTimeInterval(86400),
            end: sampleDate.addingTimeInterval(86400 + 1800),
            color: .haWarningColor
        ),
    ]

    private static let sampleLogbook: [HALogbookEntry] = [
        .init(id: "1", when: sampleDate, name: "Front door", message: "was opened", icon: .doorOpenIcon),
        .init(
            id: "2",
            when: sampleDate.addingTimeInterval(-600),
            name: "Kitchen light",
            message: "was turned on by Bruno",
            icon: .lightbulbOnIcon,
            color: .haWarningColor
        ),
        .init(
            id: "3",
            when: sampleDate.addingTimeInterval(-3600),
            name: "Alarm",
            message: "changed to disarmed",
            icon: .shieldOffOutlineIcon,
            color: .haSuccessColor
        ),
    ]
    private static let sampleTimeZone = TimeZone(identifier: "UTC") ?? .gmt

    /// Shared by the segmented bar's variants so they differ only in the option being demonstrated.
    private static let sampleSegments = [
        HABarSegment(id: "solar", value: 12.4, color: .haWarningColor, label: "Solar"),
        HABarSegment(id: "grid", value: 6.1, color: .haPrimary, label: "Grid"),
        HABarSegment(id: "battery", value: 3.2, color: .haSuccessColor, label: "Battery"),
    ]

    /// Buttons all support the same states, so each style demonstrates the same set rather than
    /// repeating a bespoke list nine times.
    private func buttonVariants(
        applyingStyle: (Button<Text>) -> some View
    ) -> [DesignSystemComponentVariant] {
        [
            .init("Enabled") { applyingStyle(Button(title) {}) },
            .init("Disabled") { applyingStyle(Button(title) {}).disabled(true) },
        ]
    }
}
#endif
