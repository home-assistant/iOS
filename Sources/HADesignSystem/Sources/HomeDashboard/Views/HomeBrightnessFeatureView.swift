#if !os(watchOS)
import SwiftUI

/// A light's brightness under its tile. Holds the slider's own value while it is being dragged and
/// calls `light.turn_on` with what it lands on — the state coming back from the server then takes
/// over again.
public struct HomeBrightnessFeatureView: View {
    @Environment(\.homeDashboard) private var context
    @State private var brightness: Double?

    private let entityId: String

    public init(entityId: String) {
        self.entityId = entityId
    }

    /// The frontend's slider runs 1–100%, not 0: zero would be "off", which is the tile's job.
    private static let scale = HASliderScale(min: 1, max: 100)

    /// Brightness comes back as 0–255 and is shown as a percentage, the way the frontend shows it.
    private var serverBrightness: Double {
        guard let raw = context.registry.state(entityId)?.attributes.brightness else {
            return 0
        }
        return (Double(raw) / 255 * 100).rounded()
    }

    public var body: some View {
        HAControlSlider(
            value: Binding(
                get: { brightness ?? serverBrightness },
                set: { newValue in
                    brightness = newValue
                    context.perform(.performAction(HomeServiceCall(
                        service: "light.turn_on",
                        entityId: entityId
                    )))
                }
            ),
            scale: Self.scale,
            label: context.strings.brightness
        )
        .frame(height: 40)
        .onChange(of: serverBrightness) { _ in
            // The server had the last word: stop showing the dragged value.
            brightness = nil
        }
    }
}

#Preview {
    HomeBrightnessFeatureView(entityId: "light.kitchen_counter")
        .environment(\.homeDashboard, HomeDashboardContext(registry: HomeDashboardSampleHome.registry))
        .padding()
}

#endif
