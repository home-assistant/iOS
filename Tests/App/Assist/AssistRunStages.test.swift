@testable import Shared
import XCTest

/// The stages decide what the backend is asked to run, and it rejects a run that asks a pipeline for
/// a stage it does not have before emitting a single event. These cover every combination of where
/// the user handles speech against what the pipeline can do.
final class AssistRunStagesTests: XCTestCase {
    private let voicePipeline = Pipeline(id: "voice", name: "Voice", sttEngine: "stt.cloud", ttsEngine: "tts.cloud")
    private let textOnlyPipeline = Pipeline(id: "text", name: "Text", sttEngine: nil, ttsEngine: " ")

    func testServerSpeechOnVoicePipelineRunsEveryStage() throws {
        let stages = try XCTUnwrap(AssistRunStages(pipeline: voicePipeline, listening: .server, speaking: .server))

        XCTAssertTrue(stages.startsWithSpeechToText)
        XCTAssertTrue(stages.endsWithTextToSpeech)
    }

    func testServerListeningOnPipelineWithoutSpeechToTextIsUnsupported() {
        XCTAssertNil(AssistRunStages(pipeline: textOnlyPipeline, listening: .server, speaking: nil))
    }

    func testOnDeviceListeningStartsWithTextWhateverThePipeline() throws {
        for pipeline in [voicePipeline, textOnlyPipeline] {
            let stages = try XCTUnwrap(AssistRunStages(pipeline: pipeline, listening: .onDevice, speaking: nil))
            XCTAssertFalse(stages.startsWithSpeechToText)
        }
    }

    func testServerSpeakingOnPipelineWithoutTextToSpeechEndsAtIntent() throws {
        let stages = try XCTUnwrap(AssistRunStages(pipeline: textOnlyPipeline, listening: .onDevice, speaking: .server))

        XCTAssertFalse(stages.endsWithTextToSpeech)
    }

    func testOnDeviceSpeakingNeverAsksTheServerToSpeak() throws {
        let stages = try XCTUnwrap(AssistRunStages(pipeline: voicePipeline, listening: .server, speaking: .onDevice))

        XCTAssertFalse(stages.endsWithTextToSpeech)
    }

    func testTypedUnspokenRequestOnlyRunsIntent() throws {
        let stages = try XCTUnwrap(AssistRunStages(pipeline: voicePipeline, listening: nil, speaking: nil))

        XCTAssertFalse(stages.startsWithSpeechToText)
        XCTAssertFalse(stages.endsWithTextToSpeech)
    }

    /// Before the pipelines are fetched the request goes out as asked, and the backend decides.
    func testUnknownPipelineIsSentAsAsked() throws {
        let stages = try XCTUnwrap(AssistRunStages(pipeline: nil, listening: .server, speaking: .server))

        XCTAssertTrue(stages.startsWithSpeechToText)
        XCTAssertTrue(stages.endsWithTextToSpeech)
    }

    func testPipelineLookupFallsBackToPreferred() {
        let cache = AssistPipelines(
            serverId: "server",
            preferredPipeline: textOnlyPipeline.id,
            pipelines: [voicePipeline, textOnlyPipeline]
        )

        XCTAssertEqual(cache.pipeline(id: voicePipeline.id)?.id, voicePipeline.id)
        XCTAssertEqual(cache.pipeline(id: nil)?.id, textOnlyPipeline.id)
        XCTAssertEqual(cache.pipeline(id: "")?.id, textOnlyPipeline.id)
        XCTAssertNil(cache.pipeline(id: "deleted"))
    }
}
