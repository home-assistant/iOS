// Vendored from HAKit (Extensions/PromiseKit) — MIT licensed, home-assistant/HAKit 0.4.14.
// The HAKit SPM manifest does not export the PromiseKit integration as a product,
// so the macOS target (which consumes HAKit via SPM, not CocoaPods) vendors these
// public-API-only extension files. Member of Shared-macOS ONLY — on iOS the
// identical code ships inside the HAKit pod (HAKit/PromiseKit subspec).

import HAKit
import PromiseKit

public extension HAConnection {
    /// Send a request
    ///
    /// Wraps a normal request send in a Promise.
    ///
    /// - SeeAlso: `HAConnection.send(_:completion:)`
    /// - Parameter request: The request to send
    /// - Returns: The promies for the request, and a block to cancel
    func send(_ request: HARequest) -> (promise: Promise<HAData>, cancel: () -> Void) {
        let (promise, seal) = Promise<HAData>.pending()
        let token = send(request, completion: { result in
            switch result {
            case let .success(data): seal.fulfill(data)
            case let .failure(error): seal.reject(error)
            }
        })
        return (promise: promise, cancel: token.cancel)
    }

    /// Send a request with a concrete response type
    ///
    /// Wraps a typed request send in a Promise.
    ///
    /// - SeeAlso: `HAConnection.send(_:completion:)`
    /// - Parameter request: The request to send
    /// - Returns: The promise for the request, and a block to cancel
    func send<T>(_ request: HATypedRequest<T>) -> (promise: Promise<T>, cancel: () -> Void) {
        let (promise, seal) = Promise<T>.pending()
        let token = send(request, completion: { result in
            switch result {
            case let .success(data): seal.fulfill(data)
            case let .failure(error): seal.reject(error)
            }
        })
        return (promise: promise, cancel: token.cancel)
    }
}
