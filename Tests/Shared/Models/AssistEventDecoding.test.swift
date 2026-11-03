import Foundation
@testable import Shared
import Testing

/// Assist pipeline event names as they arrive in JSON: each known stage maps to its case, and a
/// stage a newer server adds decodes as `unknown` instead of failing the whole event.
struct AssistEventDecodingTests {
    @Test func knownStagesDecodeToTheirCase() throws {
        let decoder = JSONDecoder()
        for event in [AssistEvent.runStart, .sttEnd, .intentProgress, .intentEnd, .ttsEnd, .error, .runEnd] {
            let data = Data("\"\(event.rawValue)\"".utf8)
            let decoded = try decoder.decode(AssistEvent.self, from: data)
            #expect(decoded == event)
        }
    }

    @Test func anUnknownStageDecodesAsUnknown() throws {
        let decoded = try JSONDecoder().decode(AssistEvent.self, from: Data("\"stage-from-the-future\"".utf8))
        #expect(decoded == .unknown)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(AssistEvent.self, from: Data("42".utf8)) }
    }
}
