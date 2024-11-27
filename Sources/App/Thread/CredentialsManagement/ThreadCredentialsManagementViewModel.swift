import Foundation
import HAKit
import Shared

struct HAThreadNetworkConfig {
    enum Source {
        case Apple
        case HomeAssistant
    }

    let id: String
    let name: String
    let source: Source
    let credentials: [ThreadCredential]
}

final class ThreadCredentialsManagementViewModel: ObservableObject {
    @Published var configs: [HAThreadNetworkConfig] = []
    @Published var isLoading = false

    private let threadClientService = Current.matter.threadClientService

    @MainActor
    func loadCredentials() async {
        configs = []
        do {
            let appleKeychainCredentials = try await threadClientService.retrieveAllCredentials()
            configs.append(.init(
                id: UUID().uuidString,
                name: "Apple Keychain",
                source: .Apple,
                credentials: appleKeychainCredentials
            ))
        } catch {
            Current.Log.error("Failed to 'retrieveAllCredentials' from thread Apple Keychain with error: \(error)")
        }
    }

    @MainActor
    func transfer(
        _ credential: ThreadCredential,
        to destination: HAThreadNetworkConfig.Source,
        completion: @escaping (Bool) -> Void
    ) {
        switch destination {
        case .Apple:
            // To be implemented when HA has a proper dataset listing similar to Apple
            break
        case .HomeAssistant:
            shareCredentialWithHomeAssistant(credential: credential.activeOperationalDataSet) { success in
                completion(success)
            }
        }
    }

    func deleteCredential(_ credential: ThreadCredential?) {
        guard let credential else {
            Current.Log.error("No credential provided to be deleted")
            return
        }

        threadClientService.deleteCredential(macExtendedAddress: credential.macExtendedAddress) { [weak self] error in
            if let error {
                Current.Log.error("Failed to delete credential with error: \(error)")
            }
            Task.detached {
                await self?.loadCredentials()
            }
        }
    }

    @MainActor
    private func shareCredentialWithHomeAssistant(credential: String, completion: @escaping (Bool) -> Void) {
        var remainingServers = Current.servers.all.count
        var successCount = 0

        let request = HARequest(type: .webSocket("thread/add_dataset_tlv"), data: [
            "tlv": credential,
            "source": "iOS-app",
        ])

        for server in Current.servers.all {
            Current.api(for: server)?.connection.send(request).promise.pipe { result in
                switch result {
                case .fulfilled:
                    successCount += 1
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to transfer thread credentials from apple to home assistant (server name: \(server.info.name): \(error.localizedDescription)"
                        )
                }

                remainingServers -= 1

                if remainingServers == 0 {
                    completion(successCount == Current.servers.all.count)
                }
            }
        }
    }
}
