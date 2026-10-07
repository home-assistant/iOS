#if !os(watchOS)
import HAIconic
import SwiftUI

/// The severity of an ``HAAlertView``, mirroring the frontend's `ha-alert` `alert-type`.
///
/// Each case carries the icon and colour `ha-alert` uses, so a caller only picks a severity.
public enum HAAlertType: String, CaseIterable, Identifiable, Sendable {
    case info
    case warning
    case error
    case success

    public var id: String { rawValue }

    /// The glyph `ha-alert` draws for this severity.
    public var icon: MaterialDesignIcons {
        switch self {
        case .info: .informationOutlineIcon
        case .warning: .alertOutlineIcon
        case .error: .alertCircleOutlineIcon
        case .success: .checkboxMarkedCircleOutlineIcon
        }
    }

    /// Tints the icon, and at 12% opacity fills the alert — the frontend draws that wash with an
    /// `::after` pseudo-element over the same colour.
    public var color: Color {
        switch self {
        case .info: .haInfoColor
        case .warning: .haWarningColor
        case .error: .haErrorColor
        case .success: .haSuccessColor
        }
    }
}

extension HAAlertType: FrontendComponent {
    public static var frontendComponentName: String { "ha-alert" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
