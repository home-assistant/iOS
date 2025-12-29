import Foundation
import PromiseKit
import Shared

@MainActor
final class ConnectionURLViewModel: ObservableObject {
    enum SaveError: LocalizedError {
        case lastURL
        case validation(String)

        var errorDescription: String? {
            switch self {
            case .lastURL:
                return L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl
            case let .validation(message):
                return message
            }
        }

        var isFinal: Bool {
            switch self {
            case .lastURL, .validation:
                return true
            }
        }
    }

    let server: Server
    let urlType: ConnectionInfo.URLType

    @Published var url: String
    @Published var useCloud: Bool
    @Published var localPush: Bool
    @Published var ssids: [String]
    @Published var hardwareAddresses: [String]
    @Published var isChecking = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var canCommitAnyway = false

    init(server: Server, urlType: ConnectionInfo.URLType) {
        self.server = server
        self.urlType = urlType

        self.url = server.info.connection.address(for: urlType)?.absoluteString ?? ""
        self.useCloud = server.info.connection.useCloud
        self.localPush = server.info.connection.isLocalPushEnabled
        self.ssids = server.info.connection.internalSSIDs ?? []
        self.hardwareAddresses = server.info.connection.internalHardwareAddresses ?? []
    }

    var placeholder: String {
        switch urlType {
        case .internal:
            return L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
        case .external:
            return L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
        case .remoteUI, .none:
            return ""
        }
    }

    func addSSID() {
        Task {
            let currentSSID = await Current.connectivity.currentWiFiSSID()
            if let currentSSID, !ssids.contains(currentSSID) {
                ssids.append(currentSSID)
            } else {
                ssids.append("")
            }
        }
    }

    func removeSSID(at index: Int) {
        ssids.remove(at: index)
    }

    func removeSSIDs(at offsets: IndexSet) {
        ssids.remove(atOffsets: offsets)
    }

    func addHardwareAddress() {
        let currentAddress = Current.connectivity.currentNetworkHardwareAddress()
        if let currentAddress, !hardwareAddresses.contains(currentAddress) {
            hardwareAddresses.append(currentAddress)
        } else {
            hardwareAddresses.append("")
        }
    }

    func removeHardwareAddress(at index: Int) {
        hardwareAddresses.remove(at: index)
    }

    func removeHardwareAddresses(at offsets: IndexSet) {
        hardwareAddresses.remove(atOffsets: offsets)
    }

    func save(onSuccess: @escaping () -> Void) {
        let givenURL = url.isEmpty ? nil : URL(string: url)

        isChecking = true

        firstly { () -> Promise<Void> in
            try self.check(url: givenURL, useCloud: self.useCloud)

            if self.useCloud, let remoteURL = self.server.info.connection.address(for: .remoteUI) {
                return Current.webhooks.sendTest(server: self.server, baseURL: remoteURL)
            }

            if let givenURL, !self.useCloud {
                return Current.webhooks.sendTest(server: self.server, baseURL: givenURL)
            }

            return .value(())
        }.ensure {
            self.isChecking = false
        }.done {
            self.commit()
            onSuccess()
        }.catch { error in
            self.handleError(error)
        }
    }

    private func check(url: URL?, useCloud: Bool) throws {
        // Validate hardware addresses
        if urlType.isAffectedByHardwareAddress {
            let pattern = "^[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}:[a-zA-Z0-9]{2}$"
            let regex = try? NSRegularExpression(pattern: pattern)

            for address in hardwareAddresses where !address.isEmpty {
                let range = NSRange(location: 0, length: address.utf16.count)
                if regex?.firstMatch(in: address, range: range) == nil {
                    throw SaveError.validation(L10n.Settings.ConnectionSection.InternalUrlHardwareAddresses.invalid)
                }
            }
        }

        // Check if removing last URL
        if url == nil {
            let existingInfo = server.info.connection
            let other: ConnectionInfo.URLType = urlType == .internal ? .external : .internal
            if existingInfo.address(for: other) == nil,
               !useCloud || !existingInfo.useCloud {
                throw SaveError.lastURL
            }
        }
    }

    private func commit() {
        let givenURL = url.isEmpty ? nil : URL(string: url)

        server.update { info in
            info.connection.set(address: givenURL, for: urlType)
            info.connection.useCloud = useCloud
            info.connection.isLocalPushEnabled = localPush
            info.connection.internalSSIDs = ssids.filter { !$0.isEmpty }
            info.connection.internalHardwareAddresses = hardwareAddresses
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        }
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription

        if let saveError = error as? SaveError {
            canCommitAnyway = !saveError.isFinal
        } else {
            canCommitAnyway = true
        }

        showError = true
    }
}
