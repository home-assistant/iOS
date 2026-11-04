import Shared
import SwiftUI

/// A horizontal gradient track with a draggable knob — the light controls' stand-in for a
/// color-picker-style slider. watchOS renders `Slider` as -/+ buttons and has no `ColorPicker`,
/// so level controls that are inherently visual (brightness, color temperature) draw their own
/// track: the gradient shows what the ends mean, the knob shows where the light currently sits,
/// and tapping or dragging anywhere on the track picks a value.
struct WatchGradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Leading-to-trailing track colors, e.g. dark → bright or warm → cool.
    let gradient: [Color]

    private static let trackHeight: CGFloat = 30
    private static let knobDiameter: CGFloat = 24
    /// Breathing room so the knob never overflows the capsule's rounded ends.
    private static let knobInset: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(.white)
                    .overlay {
                        Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 1)
                    }
                    .frame(width: Self.knobDiameter, height: Self.knobDiameter)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .offset(x: knobOffset(trackWidth: proxy.size.width))
            }
            .contentShape(Rectangle())
            // Minimum distance zero so a plain tap on the track also picks that position.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = pickedValue(atX: gesture.location.x, trackWidth: proxy.size.width)
                    }
            )
        }
        .frame(height: Self.trackHeight)
    }

    /// Where the knob travels: between the insets, over the width left after its own diameter.
    private func travelWidth(trackWidth: CGFloat) -> CGFloat {
        max(trackWidth - Self.knobDiameter - Self.knobInset * 2, 1)
    }

    private func knobOffset(trackWidth: CGFloat) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? (value - range.lowerBound) / span : 0
        return Self.knobInset + travelWidth(trackWidth: trackWidth) * min(max(fraction, 0), 1)
    }

    private func pickedValue(atX x: CGFloat, trackWidth: CGFloat) -> Double {
        let position = x - Self.knobInset - Self.knobDiameter / 2
        let fraction = min(max(position / travelWidth(trackWidth: trackWidth), 0), 1)
        return range.lowerBound + (range.upperBound - range.lowerBound) * fraction
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var brightness: Double = 60
        @State private var kelvin: Double = 3200

        var body: some View {
            List {
                Section {
                    WatchGradientSlider(
                        value: $brightness,
                        range: 0 ... 100,
                        gradient: [Color(uiColor: .init(hex: "#1A1A1A")), .white]
                    )
                    .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: "Brightness \(Int(brightness))%")
                }
                Section {
                    WatchGradientSlider(
                        value: $kelvin,
                        range: 2000 ... 6500,
                        gradient: [
                            Color(uiColor: .init(hex: "#FFA757")),
                            .white,
                            Color(uiColor: .init(hex: "#BFDDFF")),
                        ]
                    )
                    .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: "Temperature \(Int(kelvin)) K")
                }
            }
        }
    }
    return PreviewContainer()
}
