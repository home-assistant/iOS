import Foundation
@testable import HomeAssistant
import Testing

struct SendspinPairingTokenTests {
    private var referenceClientKey: Data { Data((0 ..< 32).map { UInt8($0) }) }
    private var referencePsk: SendspinPsk { SendspinPsk(bytes: Data((224 ..< 256).map { UInt8($0) }))! }

    /// The specification's reference vector for a version-0 token.
    private let reference = "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYP6BYPC4PSOLZXH5"
        + "DU6V97M5XXO74HR6LZ7J5PW674PT6X37T6757Y"

    @Test func encodesTheReferenceVector() {
        let token = SendspinPairingToken(clientKey: referenceClientKey, pairingPsk: referencePsk)
        #expect(token.string == reference)
    }

    @Test func decodesTheReferenceVector() throws {
        let token = try #require(SendspinPairingToken(string: reference))
        #expect(token.clientKey == referenceClientKey)
        #expect(token.pairingPsk == referencePsk)
    }

    /// Operators paste tokens by hand, so decoding is deliberately lenient about case and spacing.
    @Test func decodingIsLenientAboutOperatorInput() throws {
        let token = try #require(SendspinPairingToken(string: "  \(reference.lowercased())  "))
        #expect(token.clientKey == referenceClientKey)
    }

    @Test func rejectsUnknownVersions() {
        #expect(SendspinPairingToken(string: "SP:9AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQ") == nil)
    }

    @Test func rejectsTruncatedPayloads() {
        #expect(SendspinPairingToken(string: "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQ") == nil)
    }
}
