import Foundation
import Shared

final class OnboardingPermissionsNavigationViewModel: ObservableObject {

    let onboardingServer: Server

    init(onboardingServer: Server) {
        self.onboardingServer = onboardingServer
    }

    // Since user gave location access we can use it's current network SSID as Home identifier
    func addCurrentSSIDAsLocalConnectionSafeNetwork(completion: @escaping () -> Void) {
        Current.connectivity.syncNetworkInformation { [weak self] in
            if let currentSSID = Current.connectivity.currentWiFiSSID() {
                // Update SSIDs if we have access to them, since we're gonna need it later
                self?.onboardingServer.info.connection.internalSSIDs = [currentSSID]
            } else {
                Current.Log.verbose("No onboarding server or no SSID available")
            }
            completion()
        }
    }

    // When the user decides to not share it's location and use
    // local connection always no matter the risks around it
    func useLocalConnectionWithoutLocalAccessConfiguration() {
        onboardingServer.info.connection.alwaysFallbackToInternalURL = true
    }
}
