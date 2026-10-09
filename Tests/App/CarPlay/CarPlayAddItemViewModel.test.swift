import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// CarPlay Assist items talk and listen through the car, so the picker only offers pipelines the server
/// can both transcribe and speak for.
final class CarPlayAddItemViewModelTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!

    private let voicePipeline = Pipeline(id: "voice", name: "Voice", sttEngine: "stt.cloud", ttsEngine: "tts.cloud")
    private let speechToTextOnlyPipeline = Pipeline(id: "stt-only", name: "STT only", sttEngine: "stt.cloud")
    private let textOnlyPipeline = Pipeline(id: "text", name: "Text", sttEngine: " ", ttsEngine: nil)

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AssistPipelinesTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        database = nil
        super.tearDown()
    }

    func testOnlyPipelinesWithSpeechToTextAndTextToSpeechAreOffered() throws {
        try cache(preferred: voicePipeline.id)

        let pipelines = CarPlayAddItemViewModel().assistPipelines(serverId: "server")

        XCTAssertEqual(pipelines.map(\.id), ["", voicePipeline.id], "the preferred entry, then the voice pipeline")
    }

    func testPreferredEntryIsLeftOutWhenThePreferredPipelineCannotSpeak() throws {
        try cache(preferred: textOnlyPipeline.id)

        let pipelines = CarPlayAddItemViewModel().assistPipelines(serverId: "server")

        XCTAssertEqual(pipelines.map(\.id), [voicePipeline.id])
    }

    private func cache(preferred: String) throws {
        try database.write { db in
            try AssistPipelines(
                serverId: "server",
                preferredPipeline: preferred,
                pipelines: [voicePipeline, speechToTextOnlyPipeline, textOnlyPipeline]
            ).save(db)
        }
    }
}
