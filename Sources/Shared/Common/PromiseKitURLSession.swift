import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PromiseKit

// Vendored from PromiseKit/Foundation (NSURLSession+Promise.swift), MIT License.
// PromiseKit's Foundation extensions ship no modern SwiftPM product, so the
// URLSession promise API the app relies on lives here.

public protocol PMKURLRequestConvertible {
    var pmkRequest: URLRequest { get }
}

extension URLRequest: PMKURLRequestConvertible {
    public var pmkRequest: URLRequest { self }
}

extension URL: PMKURLRequestConvertible {
    public var pmkRequest: URLRequest { URLRequest(url: self) }
}

public extension URLSession {
    func dataTask(
        _: PMKNamespacer,
        with convertible: PMKURLRequestConvertible
    ) -> Promise<(data: Data, response: URLResponse)> {
        Promise { dataTask(with: convertible.pmkRequest, completionHandler: adapter($0)).resume() }
    }
}

private func adapter<T, U>(_ seal: Resolver<(data: T, response: U)>) -> (T?, U?, Error?) -> Void {
    { t, u, e in
        if let t, let u {
            seal.fulfill((t, u))
        } else if let e {
            seal.reject(e)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}

public enum PMKHTTPError: Error, LocalizedError, CustomStringConvertible {
    case badStatusCode(Int, Data, HTTPURLResponse)

    public var errorDescription: String? {
        switch self {
        case let .badStatusCode(401, _, response):
            return "Unauthorized (\(response.url?.absoluteString ?? "nil"))"
        case let .badStatusCode(code, _, response):
            return "Invalid HTTP response (\(code)) for \(response.url?.absoluteString ?? "nil")."
        }
    }

    public var description: String {
        switch self {
        case let .badStatusCode(code, data, response):
            var dict: [String: Any] = [
                "Status Code": code,
                "Body": String(data: data, encoding: .utf8) ?? "\(data.count) bytes",
            ]
            dict["URL"] = response.url
            dict["Headers"] = response.allHeaderFields
            return "<NSHTTPResponse> \(NSDictionary(dictionary: dict))"
        }
    }
}

public extension Promise where T == (data: Data, response: URLResponse) {
    func validate() -> Promise<T> {
        map {
            guard let response = $0.response as? HTTPURLResponse else { return $0 }
            switch response.statusCode {
            case 200 ..< 300:
                return $0
            case let code:
                throw PMKHTTPError.badStatusCode(code, $0.data, response)
            }
        }
    }
}
