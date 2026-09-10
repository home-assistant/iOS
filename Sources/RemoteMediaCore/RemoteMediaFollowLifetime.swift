import Foundation

/// One Follow relationship's identity, and where it sits in the order they were created.
///
/// The identity alone cannot settle a race. Registration is asynchronous and can outlive the
/// process that started it, so a registration for a relationship the user has already ended can
/// reach the server after the replacement's has — and a UUID gives the server no way to tell which
/// of the two it is looking at. Comparing them is not an option either: they are identities, not
/// values, and lexical order says nothing about time.
///
/// The sequence is what makes it decidable. It comes from a counter the host app keeps and
/// increments once per relationship, so "later" is a fact the server can check rather than infer
/// from arrival order, timestamps or task cancellation.
public struct RemoteMediaFollowLifetime: Codable, Equatable, Sendable {
    /// Which relationship this is. Random, and never compared for order.
    public let generation: String
    /// Where it sits among the relationships this install has created.
    public let sequence: Int

    /// The largest sequence that survives the trip to the device.
    ///
    /// The push relay is a Node process and JSON numbers there are doubles, so an integer beyond
    /// 2^53 - 1 would arrive at the phone rounded. Saturating instead means two relationships
    /// could share a sequence, which the server refuses as a conflict — at one new Follow per
    /// second, reaching it takes longer than the species has existed.
    public static let maximumSequence = 9_007_199_254_740_991

    public init(generation: String, sequence: Int) {
        self.generation = generation
        self.sequence = sequence
    }

    /// The next sequence after `previous`, clamped so it stays representable.
    public static func nextSequence(after previous: Int) -> Int {
        // A stored value that has been corrupted, or written by something that allowed a negative,
        // must not make the next relationship look older than the last.
        let sanitized = max(0, previous)
        // Clamped before the addition, not after: `Int.max + 1` traps, so computing the successor
        // first and capping it afterwards would crash on exactly the input the cap exists for.
        guard sanitized < maximumSequence else { return maximumSequence }
        return sanitized + 1
    }

    enum CodingKeys: String, CodingKey {
        case generation
        case sequence
    }
}
