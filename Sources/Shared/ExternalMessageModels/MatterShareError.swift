import Foundation

/// Descriptions are for the log; the frontend shows its own text.
public enum MatterShareError: Error, CustomStringConvertible {
    case invalidRequest
    /// Reachable on Mac Catalyst alone, where `canShareDevice` is false and the frontend offers nothing.
    case unsupported

    public var description: String {
        switch self {
        case .invalidRequest:
            return "the commissioning window could not be read"
        case .unsupported:
            return "sharing Matter devices is not supported on this device"
        }
    }
}
