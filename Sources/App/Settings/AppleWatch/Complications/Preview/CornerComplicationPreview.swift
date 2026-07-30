import HAWatchComplications
import Shared
import SwiftUI

/// iPhone preview of the corner complication, stacked from the watch face corner inward: icon, name,
/// value (more prominent than the name), then the gauge arcing below them all.
///
/// The real watch corner complication renders via the native `widgetCurvesContent()` / `widgetLabel`
/// APIs, which only work inside a widget host, so the layout here is the shared
/// `CornerComplicationContentView` approximation. Both sides resolve their text / gauge through
/// `CornerComplicationRenderModel`.
struct CornerComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        CornerComplicationContentView(model: renderModel)
            .environment(\.colorScheme, .dark)
    }

    private var renderModel: CornerComplicationRenderModel {
        CornerComplicationRenderModel(
            iconImage: context.iconImage,
            title: context.titleText,
            showsName: context.showsName,
            valueText: context.valueText,
            showsValue: context.showsValue,
            fraction: context.showsGauge ? context.fraction : nil,
            tint: context.tint,
            textColor: context.textColor
        )
    }
}

#if DEBUG
/// Renders every corner permutation side by side so the layout can be checked at a glance.
private struct CornerVariantsPreview: View {
    let variants: [(String, ComplicationPreviewContext)] = [
        ("Icon + name + value + gauge", .previewCorner()),
        ("Value + name + gauge", .previewCorner(showIcon: false)),
        ("Value + name", .previewCorner(showIcon: false, gauge: false)),
        ("Value only", .previewCorner(showName: false, showIcon: false, gauge: false)),
        ("Name only + gauge", .previewCorner(showValue: false, showIcon: false)),
        ("Icon + gauge", .previewCorner(showValue: false, showName: false)),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.two) {
                ForEach(variants, id: \.0) { label, context in
                    VStack(spacing: DesignSystem.Spaces.one) {
                        CornerComplicationPreview(context: context)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
                        Text(label).font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Corner variants") {
    CornerVariantsPreview()
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            AllFamiliesComplicationPreview(
                config: WatchComplicationConfig(serverId: "preview"),
                server: ServerFixture.standard,
                selectedFamily: .circular
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Solar",
                        iconName: "solar-power",
                        iconColor: "#FFD60AFF"
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(
                            showIcon: true,
                            showMin: false,
                            showMax: false,
                            tint: "#FFD60AFF",
                            gaugeStyle: WatchComplicationConfig.GaugeStyle.capacity.rawValue
                        ),
                        for: .circular
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(tint: "#FFD60AFF"),
                        for: .corner
                    )
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .corner
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Humidity",
                        iconName: "water-percent",
                        iconColor: "#64D2FFFF"
                    )
                    for family in WatchComplicationConfig.Family.allCases {
                        config.setOptions(
                            WatchComplicationConfig.FamilyOptions(showGauge: false, tint: "#64D2FFFF"),
                            for: family
                        )
                    }
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .rectangular
            )
        }
        .padding()
    }
}
#endif
