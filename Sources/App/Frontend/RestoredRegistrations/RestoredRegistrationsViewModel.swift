import Foundation
import PromiseKit
import Shared

@MainActor
/// Drives the screen shown to a device restored from another device's backup.
final class RestoredRegistrationsViewModel: ObservableObject {
    enum SetupState: Equatable {
        case waiting
        case signingIn
        case registering
        case done
        /// Left for the next launch.
        case skipped
        case failed(String)

        var title: String {
            switch self {
            case .waiting: return L10n.RestoredRegistrations.Status.waiting
            case .signingIn: return L10n.RestoredRegistrations.Status.signingIn
            case .registering: return L10n.RestoredRegistrations.Status.registering
            case .done: return L10n.RestoredRegistrations.Status.done
            case .skipped: return L10n.RestoredRegistrations.Status.skipped
            case let .failed(reason): return L10n.RestoredRegistrations.Status.failed(reason)
            }
        }

        var isInProgress: Bool {
            self == .signingIn || self == .registering
        }
    }

    struct Login: Identifiable {
        let viewModel: OnboardingAuthLoginViewModel
        let server: Server
        let position: Int
        let count: Int

        var id: ObjectIdentifier { ObjectIdentifier(viewModel) }
    }

    struct NextServer {
        let previous: Server
        let previousState: SetupState
        let next: Server
        let position: Int
        let count: Int
        let goOn: () -> Void
    }

    enum SheetContent {
        case login(Login)
        case nextServer(NextServer)
    }

    @Published private(set) var servers: [Server]
    @Published private(set) var states: [Identifier<Server>: SetupState]
    @Published private(set) var isRegistering = false
    /// One sheet for the whole run: taking it down and putting the next one up takes this screen, a sheet itself,
    /// down with it.
    @Published var sheet: SheetContent?

    var login: Login? {
        if case let .login(login)? = sheet { return login }
        return nil
    }

    var nextServer: NextServer? {
        if case let .nextServer(next)? = sheet { return next }
        return nil
    }

    var isSheetPresented: Bool {
        get { sheet != nil }
        set { if !newValue { sheet = nil } }
    }

    @Published var isReplaceConfirmationPresented = false

    private let ownership: RegistrationOwnership
    private let signIn: ServerReauthentication.SignIn
    private let onFinished: () -> Void

    init(
        servers: [Server],
        ownership: RegistrationOwnership = RegistrationOwnership(),
        signIn: @escaping ServerReauthentication.SignIn = ServerReauthentication.signIn(to:presenting:),
        onFinished: @escaping () -> Void
    ) {
        self.servers = servers
        self.states = Dictionary(uniqueKeysWithValues: servers.map { ($0.identifier, SetupState.waiting) })
        self.ownership = ownership
        self.signIn = signIn
        self.onFinished = onFinished
    }

    var serverNames: String {
        ListFormatter.localizedString(byJoining: servers.map(\.info.name))
    }

    func state(of server: Server) -> SetupState {
        states[server.identifier] ?? .waiting
    }

    var doneCount: Int {
        states.values.filter { $0 == .done }.count
    }

    var hasStarted: Bool {
        states.values.contains { $0 != .waiting }
    }

    var hasFailures: Bool {
        states.values.contains { if case .failed = $0 { return true } else { return false } }
    }

    var newDeviceTitle: String {
        if isRegistering {
            return L10n.RestoredRegistrations.settingUp
        }
        return hasFailures ? L10n.RestoredRegistrations.tryAgain : L10n.RestoredRegistrations.newDevice
    }

    func startSettingUpAsNewDevice() {
        Task {
            await setUpAsNewDevice()
        }
    }

    func setUpAsNewDevice() async {
        isRegistering = true
        defer { isRegistering = false }

        let remaining = servers.filter { state(of: $0) != .done }
        for server in remaining {
            states[server.identifier] = .waiting
        }

        defer { sheet = nil }
        for (index, server) in remaining.enumerated() {
            if index > 0 {
                await handOff(from: remaining[index - 1], to: server, position: index + 1, count: remaining.count)
            }
            do {
                states[server.identifier] = .signingIn
                try await signIn(server) { [weak self] viewModel in
                    guard let viewModel else { return }
                    self?.sheet = .login(Login(
                        viewModel: viewModel,
                        server: server,
                        position: index + 1,
                        count: remaining.count
                    ))
                }
                states[server.identifier] = .registering
                if let error = await ownership.registerAsNewDevice([server])[server] {
                    throw error
                }
                states[server.identifier] = .done
            } catch let error as PMKError where error.isCancelled {
                Current.Log.info("login to \(server.identifier) cancelled; the rest is left for the next launch")
                for left in remaining[index...] {
                    states[left.identifier] = .skipped
                }
                break
            } catch {
                Current.Log.error("failed to set up \(server.identifier) as a new device: \(error)")
                states[server.identifier] = .failed(error.localizedDescription)
            }
        }

        if !hasFailures {
            onFinished()
        }
    }

    private func handOff(from previous: Server, to next: Server, position: Int, count: Int) async {
        await withCheckedContinuation { continuation in
            // The button stays until the page replaces it, so a second tap must not resume again.
            var resumed = false
            sheet = .nextServer(NextServer(
                previous: previous,
                previousState: state(of: previous),
                next: next,
                position: position,
                count: count,
                goOn: {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume()
                }
            ))
        }
    }

    func confirmReplacingOldDevice() {
        isReplaceConfirmationPresented = true
    }

    func replaceOldDevice() {
        ownership.keepRegistrations(of: servers.filter { state(of: $0) != .done })
        onFinished()
    }
}
