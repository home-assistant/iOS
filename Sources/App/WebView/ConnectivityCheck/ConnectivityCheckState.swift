import Foundation
import Shared

enum ConnectivityCheckType: String, CaseIterable {
    case dns = "DNS Resolution"
    case port = "Port Reachability"
    case tls = "TLS Certificate"
    case server = "Server Connection"

    var localizedName: String {
        switch self {
        case .dns:
            return L10n.Connectivity.Check.dns
        case .port:
            return L10n.Connectivity.Check.port
        case .tls:
            return L10n.Connectivity.Check.tls
        case .server:
            return L10n.Connectivity.Check.server
        }
    }

    var description: String {
        switch self {
        case .dns:
            return L10n.Connectivity.Check.Dns.description
        case .port:
            return L10n.Connectivity.Check.Port.description
        case .tls:
            return L10n.Connectivity.Check.Tls.description
        case .server:
            return L10n.Connectivity.Check.Server.description
        }
    }
}

enum ConnectivityCheckResult: Equatable {
    case pending
    case running
    case success(message: String?)
    case failure(error: String)
    case skipped

    var isCompleted: Bool {
        switch self {
        case .success, .failure, .skipped:
            return true
        case .pending, .running:
            return false
        }
    }
}

struct ConnectivityCheck: Identifiable {
    let id = UUID()
    let type: ConnectivityCheckType
    var result: ConnectivityCheckResult

    init(type: ConnectivityCheckType, result: ConnectivityCheckResult = .pending) {
        self.type = type
        self.result = result
    }
}

class ConnectivityCheckState: ObservableObject {
    @Published var checks: [ConnectivityCheck] = []
    @Published var isRunning: Bool = false

    init() {
        self.checks = ConnectivityCheckType.allCases.map { ConnectivityCheck(type: $0) }
    }

    func updateCheck(type: ConnectivityCheckType, result: ConnectivityCheckResult) {
        if let index = checks.firstIndex(where: { $0.type == type }) {
            checks[index].result = result
        }
    }

    func reset() {
        checks = ConnectivityCheckType.allCases.map { ConnectivityCheck(type: $0) }
        isRunning = false
    }
}
