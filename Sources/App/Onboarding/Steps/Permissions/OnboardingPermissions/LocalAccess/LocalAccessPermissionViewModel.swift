import Foundation
import Shared

final class LocalAccessPermissionViewModel: ObservableObject {
    private let onboardingServer: Server

    init(onboardingServer: Server) {
        self.onboardingServer = onboardingServer
    }
}
