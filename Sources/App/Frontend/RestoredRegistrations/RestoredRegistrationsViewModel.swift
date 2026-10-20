import Foundation
import PromiseKit
import Shared

/// Drives the screen for the servers this device is registered with as another device, which it carries from the
/// backup it was restored from: it signs in to each again and registers as a new device, or replaces the other
/// device and keeps its registrations.
@MainActor
final class RestoredRegistrationsViewModel: ObservableObject {
    /// Where a server is in being set up as a new device.
    enum SetupState: Equatable {
        case waiting
        case signingIn
        case registering
        case done
        /// Left for the next launch: the user backed out of the run before this server's turn.
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

    /// The server a login page is up for, and its place in the run.
    struct Login: Identifiable {
        let viewModel: OnboardingAuthLoginViewModel
        let server: Server
        let position: Int
        let count: Int

        var id: ObjectIdentifier { ObjectIdentifier(viewModel) }
    }

    /// The hand-off between two servers of a run: what became of the one just finished and which one is next, so
    /// a login page never opens for a server the user did not see coming.
    struct NextServer {
        let previous: Server
        let previousState: SetupState
        let next: Server
        let position: Int
        let count: Int
        let goOn: () -> Void
    }

    /// What the sheet shows during a run: a server's login page, or the hand-off to the next one.
    enum SheetContent {
        case login(Login)
        case nextServer(NextServer)
    }

    /// The servers still registered as another device, in the order they are set up.
    @Published private(set) var servers: [Server]
    @Published private(set) var states: [Identifier<Server>: SetupState]
    @Published private(set) var isRegistering = false
    /// What the one sheet of a run shows. It stays up across the servers and swaps its content: taking it down
    /// and putting the next one up takes this screen, a sheet itself, down with it.
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
    /// Called once every server is settled or left for the next launch, which closes the screen.
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

    /// How many servers are set up as a new device, for the running count shown with many of them.
    var doneCount: Int {
        states.values.filter { $0 == .done }.count
    }

    /// Whether anything has happened yet, which is when the running count says something.
    var hasStarted: Bool {
        states.values.contains { $0 != .waiting }
    }

    /// Whether an earlier attempt left servers to try again, which is what the button offers then.
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

    /// Signs in to each server in turn and registers with it as a new device, showing where each one stands. It is
    /// one decision for all of them: cancelling a login ends the run, and that server and the ones after it are
    /// asked about again on the next launch. A server that could not be set up stays on screen to try again, and
    /// the ones already set up are left alone.
    func setUpAsNewDevice() async {
        isRegistering = true
        defer { isRegistering = false }

        let remaining = servers.filter { state(of: $0) != .done }
        for server in remaining {
            states[server.identifier] = .waiting
        }

        // One login sheet stays up for the whole run and shows each server's page in turn: taking it down and
        // putting the next one up takes this screen, a sheet itself, down with it.
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

    /// Shows what became of `previous` and that `next`'s login comes next, and waits for the user to go on.
    private func handOff(from previous: Server, to next: Server, position: Int, count: Int) async {
        await withCheckedContinuation { continuation in
            sheet = .nextServer(NextServer(
                previous: previous,
                previousState: state(of: previous),
                next: next,
                position: position,
                count: count,
                goOn: { continuation.resume() }
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
