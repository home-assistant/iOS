import Foundation

public struct HAAPIURLSessionTransportFactory: HAAPITransportFactory {
    public init() {}

    public func makeTransport(request: URLRequest, session: URLSession) -> any HAAPITransport {
        HAAPIURLSessionTransport(request: request, session: session)
    }
}
