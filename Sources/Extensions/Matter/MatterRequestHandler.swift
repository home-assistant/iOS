import HAKit
import MatterSupport
import PromiseKit
import Shared

// The extension is launched in response to `MatterAddDeviceRequest.perform()` and this class is the entry point
// for the extension operations.
class MatterRequestHandler: MatterAddDeviceExtensionRequestHandler {
    enum RequestError: Error {
        case unknownServer
        case missingServer
    }

    override func validateDeviceCredential(
        _ deviceCredential: MatterAddDeviceExtensionRequestHandler.DeviceCredential
    ) async throws {
        // Use this function to perform additional attestation checks if that is useful for your ecosystem.
    }

    override func selectWiFiNetwork(from wifiScanResults: [
        MatterAddDeviceExtensionRequestHandler.WiFiScanResult
    ]) async throws -> MatterAddDeviceExtensionRequestHandler.WiFiNetworkAssociation {
        .defaultSystemNetwork
    }

    override func selectThreadNetwork(from threadScanResults: [
        MatterAddDeviceExtensionRequestHandler.ThreadScanResult
    ]) async throws -> MatterAddDeviceExtensionRequestHandler.ThreadNetworkAssociation {
        Current.Log
            .verbose(
                "preferredNetworkMacExtendedAddress: \(String(describing: Current.settingsStore.matterLastPreferredNetWorkMacExtendedAddress))"
            )
        Current.Log
            .verbose(
                "preferredNetworkActiveOperationalDataset: \(String(describing: Current.settingsStore.matterLastPreferredNetWorkActiveOperationalDataset))"
            )
        Current.Log.verbose("threadScanResults: \(threadScanResults.map(\.networkName))")

        if let preferredNetworkMacExtendedAddress = Current.settingsStore.matterLastPreferredNetWorkMacExtendedAddress,
           let preferredNetworkActiveOperationalDataset = Current.settingsStore
           .matterLastPreferredNetWorkActiveOperationalDataset,
           let selectedNetwork = threadScanResults.first(where: { result in
               result.extendedAddress == preferredNetworkMacExtendedAddress.hexadecimal
           }) {
            // Saving credential in keychain before moving forward as required, docs: https://developer.apple.com/documentation/mattersupport/matteradddeviceextensionrequesthandler/selectthreadnetwork(from:)
            let networkToUse: MatterAddDeviceExtensionRequestHandler
                .ThreadNetworkAssociation = await withCheckedContinuation { continuation in
                    Current.matter.threadClientService.saveCredential(
                        macExtendedAddress: preferredNetworkMacExtendedAddress,
                        operationalDataSet: preferredNetworkActiveOperationalDataset
                    ) { error in
                        if let error {
                            Current.Log
                                .error(
                                    "Error saving credentials in keychain while comissioning matter device, error: \(error.localizedDescription)"
                                )
                            Current.Log.verbose("Using default system thread network")
                            continuation.resume(returning: .defaultSystemNetwork)
                        } else {
                            Current.Log.verbose("Using Home Assistant defined thread network")
                            continuation.resume(returning: .network(extendedPANID: selectedNetwork.extendedPANID))
                        }
                    }
                }

            return networkToUse
        } else {
            return .defaultSystemNetwork
        }
    }

    override func commissionDevice(
        in home: MatterAddDeviceRequest.Home?,
        onboardingPayload: String,
        commissioningID: UUID
    ) async throws {
        guard let identifier = Current.matter.lastCommissionServerIdentifier else {
            Current.Log.error("couldn't find server id for commission")
            throw RequestError.unknownServer
        }

        guard let server = Current.servers.server(for: identifier) else {
            Current.Log.error("couldn't locate server \(identifier)")
            throw RequestError.missingServer
        }

        try await Current.api(for: server).connection
            .send(.matterCommission(code: onboardingPayload))
            .promise
            .map { _ in () }
            .async()
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        []
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
        // Use this function to configure the (now) commissioned device with the given name and room.
    }
}
