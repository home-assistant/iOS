import Foundation
import Shared

/// Browses for Sendspin servers advertising `_sendspin-server._tcp`, the client-initiated half of
/// the protocol's two discovery modes.
///
/// This client never advertises `_sendspin._tcp`, so servers do not reach in: the phone decides
/// when it joins a server, which is the behaviour a battery-powered device wants.
final class SendspinServerBrowser: NSObject {
    static let serviceType = "_sendspin-server._tcp."
    private static let defaultPath = "/sendspin"

    /// Called on the main queue whenever the set of visible servers changes.
    var onChange: (([SendspinDiscoveredServer]) -> Void)?

    private(set) var servers: [SendspinDiscoveredServer] = []

    private let browser = NetServiceBrowser()
    private var resolving: [String: NetService] = [:]
    private var isRunning = false

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        browser.searchForServices(ofType: Self.serviceType, inDomain: "")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        browser.stop()
        for service in resolving.values {
            service.stop()
        }
        resolving.removeAll()
        servers.removeAll()
        onChange?(servers)
    }

    private func store(_ server: SendspinDiscoveredServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            guard servers[index] != server else { return }
            servers[index] = server
        } else {
            servers.append(server)
        }
        servers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        onChange?(servers)
    }

    private func remove(name: String) {
        guard let index = servers.firstIndex(where: { $0.id == name }) else { return }
        servers.remove(at: index)
        onChange?(servers)
    }

    private func makeServer(from service: NetService) -> SendspinDiscoveredServer? {
        guard let host = service.hostName, service.port > 0 else { return nil }
        // The TXT dictionary can carry NSNull rather than Data, which crashes a direct Swift cast,
        // so the values are unwrapped defensively — the same workaround the onboarding browser uses.
        let record = service.txtRecordData()
            .map { NetService.dictionary(fromTXTRecord: $0) as NSDictionary }
            .flatMap { $0 as? [String: Any] } ?? [:]
        let values = record.compactMapValues { value -> String? in
            guard let data = value as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        // `path` is a required TXT key; a server without one is not addressable.
        let path = values["path"] ?? Self.defaultPath
        var components = URLComponents()
        components.scheme = "ws"
        components.host = host.hasSuffix(".") ? String(host.dropLast()) : host
        components.port = service.port
        components.path = path.hasPrefix("/") ? path : "/" + path
        guard let url = components.url else { return nil }
        return SendspinDiscoveredServer(id: service.name, name: values["name"] ?? service.name, url: url)
    }
}

extension SendspinServerBrowser: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        resolving[service.name] = service
        service.resolve(withTimeout: 10)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        resolving.removeValue(forKey: service.name)
        remove(name: service.name)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Current.Log.error("Sendspin discovery failed to start: \(errorDict)")
    }
}

extension SendspinServerBrowser: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let server = makeServer(from: sender) else { return }
        store(server)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Current.Log.error("Sendspin server \(sender.name) did not resolve: \(errorDict)")
        resolving.removeValue(forKey: sender.name)
    }
}
