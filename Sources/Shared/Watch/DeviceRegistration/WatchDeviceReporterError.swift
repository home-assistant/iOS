import Foundation

/// What a watch sensor report can fail with beyond transport and registration errors.
public enum WatchDeviceReporterError: LocalizedError, Equatable {
    /// Home Assistant took the request but rejected these sensors' values; the text lists them.
    case sensorsRejected(String)

    public var errorDescription: String? {
        switch self {
        case let .sensorsRejected(description):
            return "Home Assistant rejected \(description)"
        }
    }
}
