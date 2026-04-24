import Foundation
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

    private struct CommissioningContext {
        let server: Server
        let commissioningStartedAt: Date
        let deviceRegistryBeforeCommissioning: [DeviceRegistryEntry]
        let didFetchDeviceRegistryBeforeCommissioning: Bool
    }

    private var commissioningContext: CommissioningContext?

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

        let deviceRegistryBeforeCommissioning: [DeviceRegistryEntry]
        let didFetchDeviceRegistryBeforeCommissioning: Bool

        do {
            deviceRegistryBeforeCommissioning = try await fetchDeviceRegistry(using: connection)
            didFetchDeviceRegistryBeforeCommissioning = true
            Current.Log.verbose(
                "Fetched \(deviceRegistryBeforeCommissioning.count) devices before Matter commissioning"
            )
        } catch {
            deviceRegistryBeforeCommissioning = []
            didFetchDeviceRegistryBeforeCommissioning = false
            Current.Log.error("Failed to fetch device registry before Matter commissioning: \(error)")
        }

        commissioningContext = CommissioningContext(
            server: server,
            commissioningStartedAt: Date(),
            deviceRegistryBeforeCommissioning: deviceRegistryBeforeCommissioning,
            didFetchDeviceRegistryBeforeCommissioning: didFetchDeviceRegistryBeforeCommissioning
        )

        do {
            try await connection
                .send(.matterCommission(code: onboardingPayload))
                .promise
                .map { _ in () }
                .async()
        } catch {
            commissioningContext = nil
            throw error
        }
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        []
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
        defer { commissioningContext = nil }

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Current.Log.verbose("Skipping Matter device configuration because the provided name was empty")
            return
        }

        guard let commissioningContext else {
            Current.Log.error("Missing commissioning context while configuring Matter device")
            return
        }

        guard let connection = Current.api(for: commissioningContext.server)?.connection else {
            Current.Log.error("No server available to configure commissioned Matter device")
            return
        }

        do {
            let deviceRegistryAfterCommissioning = try await fetchDeviceRegistry(using: connection)
            let addedDevices = devicesAddedDuringCommissioning(
                before: commissioningContext.deviceRegistryBeforeCommissioning,
                after: deviceRegistryAfterCommissioning,
                commissioningStartedAt: commissioningContext.commissioningStartedAt,
                didFetchDeviceRegistryBeforeCommissioning: commissioningContext
                    .didFetchDeviceRegistryBeforeCommissioning
            )

            Current.Log.verbose(
                "Matter commissioning added \(addedDevices.count) candidate devices: \(addedDevices.map(deviceNameForLogging(_:)))"
            )

            guard !addedDevices.isEmpty else {
                Current.Log.verbose("No newly added devices found after Matter commissioning")
                return
            }

            let matterConfigEntryIDs = try await fetchMatterConfigEntryIDs(using: connection)
            guard let matterDevice = addedDevices.first(where: { device in
                isMatterDevice(device, matterConfigEntryIDs: matterConfigEntryIDs)
            }) else {
                Current.Log.verbose("No Matter device was found among the newly added devices")
                return
            }

            try await renameDevice(
                id: matterDevice.id,
                to: name,
                using: connection
            )
            Current.Log.info("Renamed commissioned Matter device \(matterDevice.id) to \(name)")
        } catch {
            Current.Log.error("Failed to configure commissioned Matter device: \(error)")
        }
    }

    private func fetchDeviceRegistry(using connection: HAConnection) async throws -> [DeviceRegistryEntry] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[DeviceRegistryEntry], Error>) in
            connection.send(.configDeviceRegistryList()).promise.pipe { result in
                switch result {
                case let .fulfilled(entries):
                    continuation.resume(returning: entries)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchMatterConfigEntryIDs(using connection: HAConnection) async throws -> Set<String> {
        let configEntries = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
            [MatterConfigEntry],
            Error
        >) in
            connection.send(.configEntriesList()).promise.pipe { result in
                switch result {
                case let .fulfilled(entries):
                    continuation.resume(returning: entries)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }

        return Set(configEntries.filter { $0.domain == "matter" }.map(\.entryId))
    }

    private func renameDevice(
        id: String,
        to name: String,
        using connection: HAConnection
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(.updateDeviceRegistry(deviceId: id, nameByUser: name)).promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: ())
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func devicesAddedDuringCommissioning(
        before: [DeviceRegistryEntry],
        after: [DeviceRegistryEntry],
        commissioningStartedAt: Date,
        didFetchDeviceRegistryBeforeCommissioning: Bool
    ) -> [DeviceRegistryEntry] {
        if didFetchDeviceRegistryBeforeCommissioning {
            let existingDeviceIDs = Set(before.map(\.id))
            let addedDevices = after.filter { !existingDeviceIDs.contains($0.id) }
            if !addedDevices.isEmpty {
                return addedDevices
            }
        }

        let earliestRelevantTimestamp = commissioningStartedAt.timeIntervalSince1970 - 60
        return after.filter { device in
            max(device.createdAt ?? 0, device.modifiedAt ?? 0) >= earliestRelevantTimestamp
        }
    }

    private func isMatterDevice(
        _ device: DeviceRegistryEntry,
        matterConfigEntryIDs: Set<String>
    ) -> Bool {
        let configEntryIDs = Set((device.configEntries ?? []) + [device.primaryConfigEntry].compactMap { $0 })
        if !configEntryIDs.isEmpty, !matterConfigEntryIDs.isEmpty {
            return !matterConfigEntryIDs.isDisjoint(with: configEntryIDs)
        }

        return device.identifiers?.contains(where: { $0.first == "matter" }) == true
    }

    private func deviceNameForLogging(_ device: DeviceRegistryEntry) -> String {
        device.nameByUser ?? device.name ?? device.model ?? device.id
    }
}
