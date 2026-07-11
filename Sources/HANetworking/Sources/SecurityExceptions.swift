import Foundation

public enum SecurityExceptionError: Error {
    case invariantFailure
}

public struct SecurityExceptions: Codable, Equatable {
    private var exceptions: [SecurityException] = []

    public init(exceptions: [SecurityException] = []) {
        self.exceptions = exceptions
    }

    public var hasExceptions: Bool { !exceptions.isEmpty }

    public mutating func add(for secTrust: SecTrust) {
        if let exception = SecurityException(secTrust: secTrust) {
            exceptions.append(exception)
        }
    }

    public func evaluate(_ secTrust: SecTrust) throws {
        var baseError: CFError?
        let isAlreadyTrusted = SecTrustEvaluateWithError(secTrust, &baseError)

        guard !isAlreadyTrusted else {
            return
        }

        let baseThrowable = baseError as Error? ?? SecurityExceptionError.invariantFailure

        for exception in exceptions {
            do {
                try exception.evaluate(secTrust)
                // we want to preserve this one modifying the sec trust
                // so if it succeeds, we immediately return
                return
            } catch {
                // this one errored, so try the next one
            }
        }

        // always throw if we don't find a successful one above
        throw baseThrowable
    }

    public func evaluate(_ challenge: URLAuthenticationChallenge)
        -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let secTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        do {
            try evaluate(secTrust)
            return (.useCredential, .init(trust: secTrust))
        } catch {
            return (.rejectProtectionSpace, nil)
        }
    }
}

public struct SecurityException: Codable, Equatable {
    private var data: Data

    public init?(secTrust: SecTrust) {
        if let data = SecTrustCopyExceptions(secTrust) as Data? {
            self.data = data
        } else {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.data = Data(base64Encoded: string) ?? Data()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data.base64EncodedString())
    }

    public func evaluate(_ secTrust: SecTrust) throws {
        SecTrustSetExceptions(secTrust, data as CFData)

        var error: CFError?

        if SecTrustEvaluateWithError(secTrust, &error) {
            return
        } else {
            throw error as Error? ?? SecurityExceptionError.invariantFailure
        }
    }
}
