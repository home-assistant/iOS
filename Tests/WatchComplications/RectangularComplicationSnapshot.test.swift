import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

/// Snapshots the shared `RectangularComplicationContentView` — the exact same view the watchOS
/// complication (`RectangularComplicationView`) renders. Because the watch and the in-app editor
/// preview both drive this one view via `RectangularComplicationRenderModel`, these references are
/// the source of truth for how the rectangular complication looks; a preview that diverges will
/// change these images.
///
/// Rendered dark on a black face to mirror the watch, where the face is black and text defaults to
/// `.primary` (white). A light rendering would draw the default text black-on-black, so it isn't
/// representative and isn't captured.
struct RectangularComplicationSnapshotTests {
    @MainActor @Test func rectangularComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 220, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    /// The complication also renders in the watch face's accented and vibrant modes. This captures how
    /// the shared view *adapts* to each `widgetRenderingMode` (e.g. the gauge's value text). It does not
    /// reproduce the system's face-wide tint/desaturation compositing, which only happens on-device.
    @MainActor @Test func renderingModeVariants() {
        let model = RectangularComplicationRenderModel.sample(
            title: "Living Room",
            subtitle: "Temperature",
            bottomText: "Updated 2m ago"
        )
        for mode in [WidgetRenderingMode.fullColor, .accented, .vibrant] {
            assertSnapshot(
                of: face(model, mode: mode),
                layout: .fixed(width: 220, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: "\(mode)"
            )
        }
    }

    private func face(
        _ model: RectangularComplicationRenderModel,
        mode: WidgetRenderingMode = .fullColor
    ) -> some View {
        RectangularComplicationContentView(model: model)
            .environment(\.widgetRenderingMode, mode)
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.black)
    }

    private static var variants: [(String, RectangularComplicationRenderModel)] {
        [
            ("icon-name-gauge", .sample()),
            ("all-slots", .sample(title: "Living Room", subtitle: "Temperature", bottomText: "Updated 2m ago")),
            ("all-slots-no-min-max", .sample(
                title: "Living Room",
                subtitle: "Temperature",
                showMinMax: false,
                bottomText: "Updated 2m ago"
            )),
            ("value-as-text", .sample(title: "Front Door", subtitle: "Lock", fraction: nil, value: "Locked")),
            ("text-only", .sample(title: "Bedroom", subtitle: "All quiet", fraction: nil, showValue: false)),
            ("no-icon", .sample(icon: false, title: "Humidity", subtitle: "Bathroom", value: "54%")),
            ("no-name", .sample(title: "", value: "54%")),
            ("zero-fraction", .sample(title: "Battery", fraction: 0, value: "0%")),
            ("full-fraction", .sample(title: "Battery", fraction: 1, value: "100%")),
            ("long-text", .sample(
                title: "Basement Dehumidifier Tank",
                subtitle: "Relative humidity, second floor",
                value: "1234",
                bottomText: "Last synchronized a few moments ago"
            )),
            ("custom-text-color", .sample(
                title: "Solar",
                subtitle: "Production",
                value: "82%",
                bottomText: "Peak 4.2 kW",
                textColor: .yellow
            )),
        ]
    }
}
