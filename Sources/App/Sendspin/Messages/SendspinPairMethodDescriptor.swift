import Foundation

/// How a pairing method is offered: `locations` tells the operator where its secret is found.
struct SendspinPairMethodDescriptor: Codable, Equatable {
    let locations: [String]?
}
