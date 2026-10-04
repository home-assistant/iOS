@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays out the complication previews and the small builder controls. Template complications use plain
/// text (no Jinja), and entity complications have no entity yet, so no preview reaches for a server.
@MainActor
@Suite(.serialized)
struct ComplicationPreviewsRenderTests {
    private static func templateConfig(family: WatchComplicationConfig.Family) -> WatchComplicationConfig {
        var config = WatchComplicationConfig(
            serverId: "preview",
            widgetFamily: family,
            kind: .customTemplate,
            name: "Solar",
            iconName: "mdi:solar-power",
            iconColor: "#FFD60A",
            gaugeMin: 0,
            gaugeMax: 100,
            customTextTemplate: "4.2 kW",
            customGaugeTemplate: "0.42",
            customGaugeColorTemplate: "#FF9500",
            customIconColorTemplate: "#FFD60A",
            customTextColorTemplate: "#FFFFFF"
        )
        config.setOptions(
            WatchComplicationConfig.FamilyOptions(showIcon: true, showGauge: true, tint: "#FFD60A"),
            for: family
        )
        config.setSlotConfig(
            ComplicationSlotConfig(isVisible: true, formula: ComplicationFormula(parts: [.text("Sub")])),
            slot: .subtitle,
            for: .rectangular
        )
        config.setSlotConfig(
            ComplicationSlotConfig(isVisible: true, formula: ComplicationFormula(parts: [.text("Bottom")])),
            slot: .bottomText,
            for: .rectangular
        )
        return config
    }

    // MARK: - All families

    @Test func allFamiliesRendersEveryFamilyForATemplateComplication() {
        #expect(render(AllFamiliesComplicationPreview(
            config: Self.templateConfig(family: .circular),
            server: Server.fake(),
            selectedFamily: .circular
        )))
    }

    @Test func allFamiliesRendersTheMockFaceBeforeAnEntityIsPicked() {
        var units: [String?] = []
        #expect(render(AllFamiliesComplicationPreview(
            config: WatchComplicationConfig(serverId: "preview", name: "Pending"),
            server: Server.fake(),
            selectedFamily: .corner,
            onUnit: { units.append($0) }
        )))
        // Nothing is ever fetched without an entity, so no unit can be reported.
        #expect(units.allSatisfy { $0 == nil })
    }

    @Test func singleFamilyModeRendersEachFamily() {
        for family in WatchComplicationConfig.Family.allCases {
            #expect(render(AllFamiliesComplicationPreview(
                config: Self.templateConfig(family: family),
                server: Server.fake(),
                selectedFamily: family,
                showsOnlySelectedFamily: true
            )))
        }
    }

    @Test func compactScreenIsLandscapeForWideFamiliesOnly() {
        let rectangular = AllFamiliesComplicationPreview.compactScreenSize(for: .rectangular)
        let inline = AllFamiliesComplicationPreview.compactScreenSize(for: .inline)
        let circular = AllFamiliesComplicationPreview.compactScreenSize(for: .circular)
        let corner = AllFamiliesComplicationPreview.compactScreenSize(for: .corner)
        #expect(rectangular == CGSize(width: 220, height: 132))
        #expect(inline == rectangular)
        #expect(circular == CGSize(width: 140, height: 176))
        #expect(corner == circular)
    }

    // MARK: - Live preview

    @Test func livePreviewRendersEachFamilyForATemplateComplication() {
        for family in WatchComplicationConfig.Family.allCases {
            #expect(render(WatchComplicationLivePreview(
                config: Self.templateConfig(family: family),
                server: Server.fake()
            )))
        }
    }

    @Test func livePreviewRendersAnEntityComplicationWithoutAnEntity() {
        for family in WatchComplicationConfig.Family.allCases {
            #expect(render(WatchComplicationLivePreview(
                config: WatchComplicationConfig(serverId: "preview", widgetFamily: family, iconName: "mdi:home"),
                server: Server.fake()
            )))
        }
    }

    @Test func livePreviewFormatsValuesLikeTheWatch() {
        #expect(
            WatchComplicationLivePreview.formatValue("21.456", unit: "°C", precision: 1)
                == ComplicationRenderContext.formatValue("21.456", unit: "°C", precision: 1)
        )
        #expect(
            WatchComplicationLivePreview.formatValue("on", unit: nil, precision: nil)
                == ComplicationRenderContext.formatValue("on", unit: nil, precision: nil)
        )
    }

    // MARK: - Small controls

    @Test func familyPreviewRendersEachFamily() {
        for family in WatchComplicationConfig.Family.allCases {
            #expect(render(ComplicationFamilyPreview(family: family).frame(width: 60, height: 60)))
        }
    }

    @Test func loadingButtonRendersBothStates() {
        var taps = 0
        #expect(render(LoadingButton(title: "Update", isLoading: false) { taps += 1 }))
        #expect(render(LoadingButton(title: "Update", isLoading: true) { taps += 1 }))
        #expect(taps == 0)
    }

    @Test func iconSearchPickerRendersTheSelectedIcon() {
        var icon = MaterialDesignIcons.homeIcon
        let binding = Binding(get: { icon }, set: { icon = $0 })
        #expect(render(IconSearchPicker(selectedIcon: binding, tintColor: .green, title: "Icon")))
        #expect(icon == .homeIcon)
    }

    @Test func familySelectRendersSingleAndMultipleComplicationModes() {
        #expect(render(NavigationView {
            ComplicationFamilySelectView(
                allowMultiple: false,
                currentFamilies: [.graphicCircular, .modularSmall],
                onSaved: {}
            )
        }))
        #expect(render(NavigationView {
            ComplicationFamilySelectView(allowMultiple: true, currentFamilies: [], onSaved: {})
        }))
    }

    // MARK: - Helpers

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
