#if !os(watchOS)
import SwiftUI

/// A colour wheel: hue around the circumference, saturation from the white centre out to the rim.
/// The SwiftUI counterpart of the frontend's `ha-hs-color-picker`.
///
/// Hue runs clockwise from red at three o'clock — red, yellow, green, cyan, blue, magenta — which is
/// the order the rendered wheel shows. Saturation is the distance from the middle, so the centre is
/// white whatever the hue.
public struct HAHSColorPicker: View {
    /// Hue in degrees, `0..<360`.
    @Binding private var hue: Double
    /// Saturation, `0...1`.
    @Binding private var saturation: Double
    private let diameter: CGFloat
    private let isDisabled: Bool

    /// - Parameter diameter: Taken explicitly, as the gauge's is: the wheel is drawn from gradients
    ///   with no size of their own.
    public init(
        hue: Binding<Double>,
        saturation: Binding<Double>,
        diameter: CGFloat = 220,
        isDisabled: Bool = false
    ) {
        _hue = hue
        _saturation = saturation
        self.diameter = diameter
        self.isDisabled = isDisabled
    }

    private static let cursorDiameter: CGFloat = 24

    /// The full hue circle as discrete stops. `AngularGradient` interpolates between them, so a
    /// stop every 30° is enough to read as continuous while keeping the primaries where they belong.
    private var hueStops: [Color] {
        stride(from: 0, through: 360, by: 30).map { degrees in
            Color(hue: (degrees.truncatingRemainder(dividingBy: 360)) / 360, saturation: 1, brightness: 1)
        }
    }

    /// Where the cursor sits: `saturation` out along the `hue` bearing, from the centre.
    private var cursorOffset: CGSize {
        let radius = (diameter - Self.cursorDiameter) / 2 * Swift.min(Swift.max(saturation, 0), 1)
        let radians = hue * .pi / 180
        return CGSize(width: radius * cos(radians), height: radius * sin(radians))
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: hueStops, center: .center))
            // Saturation washes the hue out towards the middle, leaving white at the centre.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
            Circle()
                .fill(Color(hue: hue / 360, saturation: saturation, brightness: 1))
                .frame(width: Self.cursorDiameter, height: Self.cursorDiameter)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 2)
                .offset(cursorOffset)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard !isDisabled else { return }
                    let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                    let dx = drag.location.x - centre.x
                    let dy = drag.location.y - centre.y
                    let radius = (diameter - Self.cursorDiameter) / 2
                    saturation = Swift.min(sqrt(dx * dx + dy * dy) / radius, 1)
                    // `atan2` returns −π…π; the wheel wants 0..<360 measured the same way round.
                    hue = (atan2(dy, dx) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
                }
        )
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(hue))°, \(Int(saturation * 100))%"))
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAHSColorPicker(hue: .constant(0), saturation: .constant(0))
        HAHSColorPicker(hue: .constant(30), saturation: .constant(0.9), diameter: 140)
        HAHSColorPicker(hue: .constant(210), saturation: .constant(0.6), diameter: 140)
    }
    .padding()
}

extension HAHSColorPicker: FrontendComponent {
    public static var frontendComponentName: String { "ha-hs-color-picker" }
}

#endif
