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
                "threadScanResults: \(threadScanResults.map { "Network name: \($0.networkName), Extended PAN ID: \($0.extendedPANID), Mac extended address: \($0.extendedAddress.hexadecimal)" })"
            )
        Current.Log
            .verbose(
                "Preferred Extended PAN ID (UInt64): \(String(describing: UInt64(Current.settingsStore.matterLastPreferredNetWorkExtendedPANID ?? "", radix: 16)))"
            )
        if let matterLastPreferredNetWorkExtendedPANID = Current.settingsStore.matterLastPreferredNetWorkExtendedPANID,
           let preferredExtendedPANID = UInt64(matterLastPreferredNetWorkExtendedPANID, radix: 16),
           let selectedNetwork = threadScanResults.first(where: { result in
               result.extendedPANID == preferredExtendedPANID
           }) {
            Current.Log.verbose("Using selected thread network, name: \(selectedNetwork.networkName)")
            return .network(extendedPANID: selectedNetwork.extendedPANID)
        } else {
            Current.Log.verbose("Using default thread network")
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

        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No server available to comission matter device")
            throw HomeAssistantAPI.APIError.noAPIAvailable
        }

        try await connection
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
