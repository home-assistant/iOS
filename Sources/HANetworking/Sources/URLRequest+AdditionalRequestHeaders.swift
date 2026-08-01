import Foundation

public extension URLRequest {
    mutating func addAdditionalRequestHeaders(from connection: ConnectionInfo) {
        for header in connection.additionalRequestHeaders(for: url) where !hasHTTPHeader(named: header.name) {
            setValue(header.value, forHTTPHeaderField: header.name)
        }
    }

    private func hasHTTPHeader(named name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return allHTTPHeaderFields?.keys.contains { $0.lowercased() == lowercasedName } == true
    }
}
