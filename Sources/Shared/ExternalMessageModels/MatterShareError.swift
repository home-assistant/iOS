import Foundation

public enum MatterShareError: LocalizedError {
    /// The setup code the frontend sent could not be turned into a setup payload.
    case invalidRequest
    /// This platform cannot share Matter devices.
    case unsupported

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The setup code could not be read"
        case .unsupported:
            return "Sharing Matter devices is not supported on this device"
        }
    }
}
