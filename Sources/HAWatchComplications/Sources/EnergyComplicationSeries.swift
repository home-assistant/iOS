import SwiftUI
import UIKit

/// One flow of the energy dashboard, in the terms both the figures and the chart are drawn in.
///
/// The colours are the frontend's own energy variables, matching `WidgetEnergyPalette` on iOS so a
/// complication and the phone's Energy widget read as the same thing. They are literal values rather
/// than adaptive ones: a watch face is always dark, and `UIColor`'s trait-resolving initialiser
/// doesn't exist on watchOS anyway.
public enum EnergyComplicationSeries: String, Codable, Sendable, CaseIterable {
    /// Solar generation — frontend `--energy-solar-color` (#ff9800).
    case solar
    /// Energy consumed from the grid — `--energy-grid-consumption-color` (#488fc2).
    case grid
    /// Energy returned to the grid — `--energy-grid-return-color` (#8353d1).
    case gridReturn
    /// Energy the battery gave back — `--energy-battery-out-color` (#4db6ac).
    case batteryOut
    /// Energy that went into the battery — `--energy-battery-in-color` (#f06292).
    case batteryIn
    /// Gas consumption. The frontend's `--energy-gas-color` (#8e021b) is a near-black red made for a
    /// light dashboard, so the face gets the lightened variant the widget uses in dark mode.
    case gas

    public var color: Color {
        switch self {
        case .solar: Color(red: 1.0, green: 0.596, blue: 0.0)
        case .grid: Color(red: 0.282, green: 0.561, blue: 0.761)
        case .gridReturn: Color(red: 0.514, green: 0.325, blue: 0.820)
        case .batteryOut: Color(red: 0.302, green: 0.714, blue: 0.675)
        case .batteryIn: Color(red: 0.941, green: 0.384, blue: 0.573)
        case .gas: Color(red: 0.902, green: 0.318, blue: 0.376)
        }
    }

    /// SF Symbol standing in for the widget's Material Design icon. The complications package
    /// deliberately carries neither the icon font nor SFSafeSymbols, and the system draws these at
    /// complication sizes far better than a glyph from a bundled font would.
    public var symbolName: String {
        switch self {
        case .solar: "sun.max.fill"
        case .grid, .gridReturn: "bolt.fill"
        case .batteryOut, .batteryIn: "battery.100percent"
        case .gas: "flame.fill"
        }
    }

    /// ``symbolName`` as a template image. Built through `UIImage` rather than the SwiftUI symbol
    /// initialiser, which is what keeps this lean package free of an SFSafeSymbols dependency —
    /// the same route the other complication views take for their sample icons.
    public var symbolImage: Image {
        Image(uiImage: (UIImage(systemName: symbolName) ?? UIImage()).withRenderingMode(.alwaysTemplate))
    }
}
