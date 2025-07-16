import Foundation

public enum AppConfiguration: Int, CaseIterable, CustomStringConvertible, Equatable {
    case fastlaneSnapshot
    case debug
    case beta
    case release

    public var description: String {
        switch self {
        case .fastlaneSnapshot:
            return "fastlane"
        case .debug:
            return "debug"
        case .beta:
            return "beta"
        case .release:
            return "release"
        }
    }
}
