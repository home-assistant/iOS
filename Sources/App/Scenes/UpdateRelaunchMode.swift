import Foundation

enum UpdateRelaunchMode: String {
    case foreground
    case background

    static let argumentName = "--ha-relaunch-mode"

    static let launch = parse(arguments: ProcessInfo.processInfo.arguments)

    static func parse(arguments: [String]) -> UpdateRelaunchMode? {
        guard let index = arguments.firstIndex(of: argumentName),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return UpdateRelaunchMode(rawValue: arguments[index + 1])
    }
}
