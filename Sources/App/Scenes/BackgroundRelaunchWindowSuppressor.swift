import Foundation

final class BackgroundRelaunchWindowSuppressor {
    static let shared = BackgroundRelaunchWindowSuppressor(isSuppressing: UpdateRelaunchMode.launch == .background)

    private(set) var isSuppressing: Bool

    init(isSuppressing: Bool) {
        self.isSuppressing = isSuppressing
    }

    func windowWasRequested() {
        isSuppressing = false
    }

    func shouldDestroyScene(hasUserActivities: Bool, hasURLContexts: Bool) -> Bool {
        if hasUserActivities || hasURLContexts {
            isSuppressing = false
            return false
        }
        return isSuppressing
    }
}
