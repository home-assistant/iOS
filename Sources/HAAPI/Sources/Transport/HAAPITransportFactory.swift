import Foundation

public protocol HAAPITransportFactory: Sendable {
    func makeTransport(request: URLRequest, session: URLSession) -> any HAAPITransport
}
