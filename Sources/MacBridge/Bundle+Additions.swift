import Foundation

extension Bundle {
    var isRunningInExtension: Bool {
        Bundle.main.bundlePath.contains("PlugIns")
    }
}