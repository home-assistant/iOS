import Foundation

public enum HASecTrustExceptionUnknownError: Error {
    case invariantFailure
}

public struct HASecTrustExceptionContainer: Codable, Equatable {
    public var exceptions: [HASecTrustException] = []

    public init(exceptions: [HASecTrustException] = []) {
        self.exceptions = exceptions
    }

    public mutating func add(for secTrust: SecTrust) {
        exceptions.append(.init(secTrust: secTrust))
    }

    public func evaluate(_ secTrust: SecTrust) throws {
        var baseError: CFError?
        let isAlreadyTrusted = SecTrustEvaluateWithError(secTrust, &baseError)

        guard !isAlreadyTrusted else {
            return
        }

        let baseThrowable = baseError as Error? ?? HASecTrustExceptionUnknownError.invariantFailure

        guard !exceptions.isEmpty else {
            // without exceptions, we still need to throw
            throw baseThrowable
        }

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

        throw baseThrowable
    }
}

public struct HASecTrustException: Codable, Equatable {
    private var data: Data

    public init(secTrust: SecTrust) {
        self.data = SecTrustCopyExceptions(secTrust) as Data
    }

    public init(data: Data) {
        self.data = data
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
            throw error as Error? ?? HASecTrustExceptionUnknownError.invariantFailure
        }
    }
}
