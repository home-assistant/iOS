import Foundation
import Shared

@MainActor
final class ThreadCredentialSharingModeViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    static let extendedPANIDLength = 16

    @Published var extendedPANID = ""
    @Published private(set) var credentials: [ThreadCredential] = []
    @Published private(set) var isLoadingCredentials = false
    @Published private(set) var state: State = .idle

    private let threadClientService: ThreadClientProtocol
    private var needsCredentialLoad: Bool

    init(
        threadClientService: ThreadClientProtocol = Current.matter.threadClientService,
        credentials: [ThreadCredential]? = nil,
        extendedPANID: String = "",
        state: State = .idle
    ) {
        self.threadClientService = threadClientService
        self.credentials = credentials ?? []
        self.extendedPANID = extendedPANID
        self.state = state
        self.needsCredentialLoad = credentials == nil
    }

    var sanitizedExtendedPANID: String {
        var value = extendedPANID
            .lowercased()
            .filter { !$0.isWhitespace && $0 != ":" && $0 != "-" }
        if value.hasPrefix("0x") {
            value.removeFirst(2)
        }
        return value
    }

    var isExtendedPANIDValid: Bool {
        let value = sanitizedExtendedPANID
        return value.count == Self.extendedPANIDLength && value.allSatisfy(\.isHexDigit)
    }

    var canEnableSharingMode: Bool {
        isExtendedPANIDValid && state != .loading
    }

    func loadCredentialsIfNeeded() async {
        guard needsCredentialLoad else { return }
        await loadCredentials()
    }

    func loadCredentials() async {
        needsCredentialLoad = false
        isLoadingCredentials = true
        defer { isLoadingCredentials = false }
        do {
            credentials = try await threadClientService.retrieveAllCredentials()
        } catch {
            Current.Log.error("Failed to retrieve Thread credentials for credential sharing mode: \(error)")
            credentials = []
        }
    }

    func select(_ credential: ThreadCredential) {
        guard state != .loading else { return }
        extendedPANID = credential.extendedPANID
        state = .idle
    }

    func enableSharingMode() async {
        guard canEnableSharingMode else { return }
        state = .loading
        let extendedPANID = sanitizedExtendedPANID
        do {
            try await threadClientService.enableCredentialSharingMode(extendedPANID: extendedPANID)
            Current.Log.info("Thread credential sharing mode enabled for extended PAN ID \(extendedPANID)")
            state = .success
        } catch {
            Current.Log.error("Failed to enable Thread credential sharing mode: \(error)")
            state = .failure(error.localizedDescription)
        }
    }
}
