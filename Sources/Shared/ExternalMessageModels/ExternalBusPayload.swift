import Foundation

/// A protocol for payloads that can be parsed from a dictionary.
public protocol ExternalBusPayload {
    /// The unique identifier for this payload.
    var id: String { get }

    /// Creates a payload from a dictionary, returning nil if required fields are missing or invalid.
    init?(payload: [String: Any]?)
}
