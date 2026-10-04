import Foundation
import GRDB
import HAKit
@testable import Shared
import XCTest

/// Decoding of the Assist pipeline payloads, and the database-backed pipeline cache.
final class AssistModelTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        database = nil
        super.tearDown()
    }

    // MARK: - PipelineResponse / Pipeline

    func testPipelineResponseDecodesEveryPipelineField() throws {
        let response = try PipelineResponse(data: .dictionary([
            "preferred_pipeline": "pipeline-1",
            "pipelines": [
                [
                    "conversation_engine": "conversation.home_assistant",
                    "conversation_language": "en",
                    "id": "pipeline-1",
                    "language": "en-US",
                    "name": "Home Assistant",
                    "stt_engine": "stt.cloud",
                    "stt_language": "en-GB",
                    "tts_engine": "tts.cloud",
                    "tts_language": "en-AU",
                    "tts_voice": "Jenny",
                    "wake_word_entity": "wake_word.openwakeword",
                    "wake_word_id": "ok_nabu",
                ],
                [
                    "id": "pipeline-2",
                    "name": "Minimal",
                ],
            ],
        ]))

        XCTAssertEqual(response.preferredPipeline, "pipeline-1")
        XCTAssertEqual(response.pipelines.count, 2)

        let full = response.pipelines[0]
        XCTAssertEqual(full.id, "pipeline-1")
        XCTAssertEqual(full.name, "Home Assistant")
        XCTAssertEqual(full.conversationEngine, "conversation.home_assistant")
        XCTAssertEqual(full.conversationLanguage, "en")
        XCTAssertEqual(full.language, "en-US")
        XCTAssertEqual(full.sttEngine, "stt.cloud")
        XCTAssertEqual(full.sttLanguage, "en-GB")
        XCTAssertEqual(full.ttsEngine, "tts.cloud")
        XCTAssertEqual(full.ttsLanguage, "en-AU")
        XCTAssertEqual(full.ttsVoice, "Jenny")
        XCTAssertEqual(full.wakeWordEntity, "wake_word.openwakeword")
        XCTAssertEqual(full.wakeWordId, "ok_nabu")

        let minimal = response.pipelines[1]
        XCTAssertEqual(minimal.id, "pipeline-2")
        XCTAssertEqual(minimal.name, "Minimal")
        XCTAssertNil(minimal.conversationEngine)
        XCTAssertNil(minimal.language)
        XCTAssertNil(minimal.ttsVoice)
        XCTAssertNil(minimal.wakeWordId)
    }

    func testPipelineWithoutAnIdFailsToDecode() {
        XCTAssertThrowsError(try Pipeline(data: .dictionary(["name": "No id"])))
    }

    func testPipelineResponseWithoutPreferredPipelineFailsToDecode() {
        XCTAssertThrowsError(try PipelineResponse(data: .dictionary(["pipelines": [[String: Any]]()])))
    }

    func testPipelineResponseMemberwiseInit() {
        let response = PipelineResponse(
            preferredPipeline: "p",
            pipelines: [Pipeline(id: "p", name: "P")]
        )

        XCTAssertEqual(response.preferredPipeline, "p")
        XCTAssertEqual(response.pipelines.map(\.id), ["p"])
    }

    // MARK: - AssistResponse

    func testIntentEndResponseDecodesTheSpokenAnswer() throws {
        let response = try AssistResponse(data: .dictionary([
            "type": "intent-end",
            "timestamp": "2026-09-22T16:59:52.000000+00:00",
            "data": [
                "language": "en",
                "intent_output": [
                    "conversation_id": "conversation-1",
                    "continue_conversation": true,
                    "response": ["speech": ["plain": ["speech": "Turned on the lights"]]],
                ],
            ],
        ]))

        XCTAssertEqual(response.type, .intentEnd)
        XCTAssertEqual(response.timestamp, "2026-09-22T16:59:52.000000+00:00")
        XCTAssertEqual(response.data?.language, "en")
        XCTAssertEqual(response.data?.intentOutput?.conversationId, "conversation-1")
        XCTAssertEqual(response.data?.intentOutput?.continueConversation, true)
        XCTAssertEqual(response.data?.intentOutput?.response?.speech.plain.speech, "Turned on the lights")
    }

    func testIntentOutputDefaultsToNotContinuingTheConversation() throws {
        let response = try AssistResponse(data: .dictionary([
            "type": "intent-end",
            "timestamp": "t",
            "data": ["intent_output": ["conversation_id": "c"]],
        ]))

        XCTAssertEqual(response.data?.intentOutput?.continueConversation, false)
        XCTAssertNil(response.data?.intentOutput?.response)
    }

    func testRunStartResponseDecodesRunnerData() throws {
        let response = try AssistResponse(data: .dictionary([
            "type": "run-start",
            "timestamp": "t",
            "data": ["runner_data": ["stt_binary_handler_id": 3, "timeout": 300]],
        ]))

        XCTAssertEqual(response.type, .runStart)
        XCTAssertEqual(response.data?.runnerData?.sttBinaryHandlerId, 3)
        XCTAssertEqual(response.data?.runnerData?.timeout, 300)
    }

    func testStageOutputsDecode() throws {
        let stt = try AssistResponse(data: .dictionary([
            "type": "stt-end",
            "timestamp": "t",
            "data": ["stt_output": ["text": "what time is it"]],
        ]))
        XCTAssertEqual(stt.type, .sttEnd)
        XCTAssertEqual(stt.data?.sttOutput?.text, "what time is it")

        let tts = try AssistResponse(data: .dictionary([
            "type": "tts-end",
            "timestamp": "t",
            "data": ["tts_output": ["url": "/api/tts_proxy/abc.mp3"]],
        ]))
        XCTAssertEqual(tts.type, .ttsEnd)
        XCTAssertEqual(tts.data?.ttsOutput?.urlPath, "/api/tts_proxy/abc.mp3")

        let progress = try AssistResponse(data: .dictionary([
            "type": "intent-progress",
            "timestamp": "t",
            "data": ["chat_log_delta": ["content": "Hel"]],
        ]))
        XCTAssertEqual(progress.type, .intentProgress)
        XCTAssertEqual(progress.data?.chatLogDelta?.content, "Hel")

        let error = try AssistResponse(data: .dictionary([
            "type": "error",
            "timestamp": "t",
            "data": ["code": "stt-no-text-recognized", "message": "No text recognized"],
        ]))
        XCTAssertEqual(error.type, .error)
        XCTAssertEqual(error.data?.code, "stt-no-text-recognized")
        XCTAssertEqual(error.data?.message, "No text recognized")
    }

    func testUnknownEventTypeDecodesAsUnknown() throws {
        let response = try AssistResponse(data: .dictionary([
            "type": "something-new",
            "timestamp": "t",
        ]))

        XCTAssertEqual(response.type, .unknown)
        XCTAssertNil(response.data)
    }

    func testResponseWithoutTimestampFailsToDecode() {
        XCTAssertThrowsError(try AssistResponse(data: .dictionary(["type": "run-start"])))
    }

    func testAssistEventDecodableFallsBackToUnknown() throws {
        let events = try JSONDecoder().decode(
            [AssistEvent].self,
            from: Data(#"["run-start", "wake_word-end", "not-an-event"]"#.utf8)
        )

        XCTAssertEqual(events, [.runStart, .wakeWordEnd, .unknown])
    }

    // MARK: - AssistPipelines

    func testAssistPipelinesInitFromPipelineResponse() {
        let pipelines = AssistPipelines(
            serverId: "server-1",
            pipelineResponse: PipelineResponse(
                preferredPipeline: "p2",
                pipelines: [Pipeline(id: "p1", name: "One"), Pipeline(id: "p2", name: "Two")]
            )
        )

        XCTAssertEqual(pipelines.serverId, "server-1")
        XCTAssertEqual(pipelines.preferredPipeline, "p2")
        XCTAssertEqual(pipelines.pipelines.map(\.id), ["p1", "p2"])
    }

    func testConfigReadsEveryStoredServer() throws {
        try database.write { db in
            try AssistPipelines(serverId: "a", preferredPipeline: "p", pipelines: [Pipeline(id: "p", name: "P")])
                .insert(db)
            try AssistPipelines(serverId: "b", preferredPipeline: "q", pipelines: []).insert(db)
        }

        let config = try XCTUnwrap(AssistPipelines.config())

        XCTAssertEqual(config.map(\.serverId).sorted(), ["a", "b"])
        XCTAssertEqual(config.first(where: { $0.serverId == "a" })?.pipelines.map(\.name), ["P"])
    }

    func testConfigIsEmptyWithNothingStored() throws {
        XCTAssertEqual(try AssistPipelines.config()?.count, 0)
    }

    func testDeleteOrphansKeepsOnlyKnownServers() throws {
        try database.write { db in
            try AssistPipelines(serverId: "kept", preferredPipeline: "p", pipelines: []).insert(db)
            try AssistPipelines(serverId: "orphan", preferredPipeline: "p", pipelines: []).insert(db)
        }

        try AssistPipelines.deleteOrphans(keepingServerIds: ["kept"])

        let remaining = try database.read { db in
            try AssistPipelines.fetchAll(db).map(\.serverId)
        }
        XCTAssertEqual(remaining, ["kept"])
    }

    func testDeleteOrphansWithNoServersClearsEverything() throws {
        try database.write { db in
            try AssistPipelines(serverId: "a", preferredPipeline: "p", pipelines: []).insert(db)
        }

        try AssistPipelines.deleteOrphans(keepingServerIds: [])

        let count = try database.read { db in try AssistPipelines.fetchCount(db) }
        XCTAssertEqual(count, 0)
    }
}
