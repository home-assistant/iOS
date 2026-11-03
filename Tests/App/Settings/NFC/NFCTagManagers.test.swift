#if !targetEnvironment(macCatalyst)
import CoreNFC
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing

/// The parts of the NFC reader, writer and tag managers that run without a tag in range: error texts,
/// the record a write picks for a tag's capacity, reading a tag identifier out of a message, and the
/// simulator's stand-in manager. Starting a real NFC session needs the hardware.
struct NFCTagManagersTests {
    @Test func readerAndWriterErrorsDescribeThemselves() {
        let writerErrors: [NFCWriter.NFCWriterError] = [
            .invalidFormat,
            .notWritable,
            .insufficientCapacity(required: 120, available: 48),
        ]
        for error in writerErrors {
            #expect(error.errorDescription?.isEmpty == false)
        }
        #expect(NFCReader.NFCReaderError.unsupportedTag.errorDescription?.isEmpty == false)
        #expect(NFCReader.NFCReaderError.readFailed.errorDescription?.isEmpty == false)
    }

    /// A write includes the optional Android record when the tag has room, falls back to the
    /// required record alone, and fails when even that does not fit.
    @Test func aWritePicksTheLargestMessageThatFits() throws {
        let uri = try #require(NFCNDEFPayload.wellKnownTypeURIPayload(
            url: URL(string: "https://www.home-assistant.io/tag/front-door")!
        ))
        let android = try #require(NFCNDEFPayload.androidPackage(payload: "io.homeassistant.companion.android"))
        let required = NFCNDEFMessage(records: [uri])
        let optional = NFCNDEFMessage(records: [uri, android])

        let roomy = try NFCWriter.message(for: optional.length, required: required, optional: optional)
        #expect(roomy.records.count == 2)
        let tight = try NFCWriter.message(for: required.length, required: required, optional: optional)
        #expect(tight.records.count == 1)

        do {
            _ = try NFCWriter.message(for: required.length - 1, required: required, optional: optional)
            Issue.record("Expected the message not to fit")
        } catch let NFCWriter.NFCWriterError.insufficientCapacity(required: needed, available: available) {
            #expect(needed == required.length)
            #expect(available == required.length - 1)
        }
    }

    @Test func aTagIdentifierIsReadFromTheFirstHomeAssistantRecord() async throws {
        let other = try #require(NFCNDEFPayload.wellKnownTypeURIPayload(url: URL(string: "https://example.com/x")!))
        let tag = try #require(NFCNDEFPayload.wellKnownTypeURIPayload(
            url: URL(string: "https://www.home-assistant.io/tag/front-door")!
        ))

        let identifier = try await Self.value(iOSTagManager.identifier(from: NFCNDEFMessage(records: [other, tag])))
        #expect(identifier == "front-door")

        await #expect(throws: (any Error).self) {
            _ = try await Self.value(iOSTagManager.identifier(from: NFCNDEFMessage(records: [other])))
        }
    }

    #if targetEnvironment(simulator)
    @Test func theSimulatorPretendsToReadAndWriteTags() async throws {
        let manager = SimulatorTagManager()
        #expect(manager.isNFCAvailable)

        let read = try await Self.value(manager.readNFC())
        #expect(!read.isEmpty)
        let written = try await Self.value(manager.writeNFC(value: "garage"))
        #expect(written == "garage")
        try await Self.value(
            manager.writeNFC(deeplink: URL(string: "homeassistant://navigate/lovelace")!, alertMessage: "")
        )
    }

    /// The simulator has no NFC reader, which the real manager reports.
    @Test func theRealManagerReportsNoReaderOnTheSimulator() {
        #expect(!iOSTagManager().isNFCAvailable)
    }
    #endif

    private static func value<T>(_ promise: Promise<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            promise.done { continuation.resume(returning: $0) }.catch { continuation.resume(throwing: $0) }
        }
    }
}
#endif
