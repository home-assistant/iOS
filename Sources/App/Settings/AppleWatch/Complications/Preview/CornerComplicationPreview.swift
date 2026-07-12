import Shared
import SwiftUI

/// iPhone preview of the corner complication: content tucked into the watch face corner with a shallow
/// arc gauge following the simulated watch's top-trailing curve.
struct CornerComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if context.showsGauge, let fraction = context.fraction {
                Group {
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: 8, y: 92),
                            radius: 86,
                            startAngle: .degrees(-48),
                            endAngle: .degrees(-18),
                            clockwise: false
                        )
                    }
                    .stroke(context.tint.opacity(0.28), style: StrokeStyle(lineWidth: 6, lineCap: .round))

                    Path { path in
                        path.addArc(
                            center: CGPoint(x: 8, y: 92),
                            radius: 86,
                            startAngle: .degrees(-48),
                            endAngle: .degrees(-48 + (30 * fraction)),
                            clockwise: false
                        )
                    }
                    .stroke(context.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                }
                .offset(x: -12, y: -16)
            }

            if context.showsValue, !context.value.isEmpty {
                Text(context.value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(context.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(6)
                    .rotationEffect(.degrees(45))
            }
        }
        .offset(x: -12, y: 12)
        .frame(width: 100, height: 100)
        .environment(\.colorScheme, .dark)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            AllFamiliesComplicationPreview(
                config: WatchComplicationConfig(serverId: "preview"),
                server: ServerFixture.standard,
                selectedFamily: .constant(.circular)
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
                selectedFamily: .constant(.corner)
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
                selectedFamily: .constant(.rectangular)
            )
        }
        .padding()
    }
}
#endif
