import AVFoundation
@testable import HomeAssistant
import XCTest

final class CarPlayAssistTonePlayerTests: XCTestCase {
    private var appBundle: Bundle {
        Bundle(for: CarPlayAssistTonePlayer.self)
    }

    func testEveryToneHasABundledSound() {
        for tone in CarPlayAssistTonePlayer.Tone.allCases {
            XCTAssertNotNil(
                appBundle.url(
                    forResource: tone.resourceName,
                    withExtension: CarPlayAssistTonePlayer.Tone.resourceExtension
                ),
                "\(tone) has no bundled sound"
            )
        }
    }

    func testPlayCompletesImmediatelyWhenTheSoundIsMissing() {
        let sut = CarPlayAssistTonePlayer(bundle: Bundle(for: CarPlayAssistTonePlayerTests.self))
        let completed = expectation(description: "completion")

        sut.play(.listening) { completed.fulfill() }

        wait(for: [completed], timeout: 0.1)
    }

    func testPlayCompletesWhenTheSoundFinishes() {
        let sut = CarPlayAssistTonePlayer(bundle: appBundle)
        let completed = expectation(description: "completion")

        sut.play(.error) { completed.fulfill() }

        wait(for: [completed], timeout: 5)
    }

    func testStopDropsThePendingCompletion() {
        let sut = CarPlayAssistTonePlayer(bundle: appBundle)
        let completed = expectation(description: "completion")
        completed.isInverted = true

        sut.play(.error) { completed.fulfill() }
        sut.stop()

        wait(for: [completed], timeout: 1.5)
    }

    func testPlayingAnotherToneDropsThePreviousCompletion() {
        let sut = CarPlayAssistTonePlayer(bundle: appBundle)
        let firstCompleted = expectation(description: "first completion")
        firstCompleted.isInverted = true
        let secondCompleted = expectation(description: "second completion")

        sut.play(.listening) { firstCompleted.fulfill() }
        sut.play(.error) { secondCompleted.fulfill() }

        wait(for: [firstCompleted, secondCompleted], timeout: 5)
    }

    func testCallbacksFromAnotherPlayerAreIgnored() throws {
        let sut = CarPlayAssistTonePlayer(bundle: appBundle)
        let url = try XCTUnwrap(appBundle.url(
            forResource: CarPlayAssistTonePlayer.Tone.processing.resourceName,
            withExtension: CarPlayAssistTonePlayer.Tone.resourceExtension
        ))
        let otherPlayer = try AVAudioPlayer(contentsOf: url)
        let completedEarly = expectation(description: "completion before the sound finished")
        completedEarly.isInverted = true

        sut.play(.processing) { completedEarly.fulfill() }
        sut.audioPlayerDidFinishPlaying(otherPlayer, successfully: true)
        sut.audioPlayerDecodeErrorDidOccur(otherPlayer, error: nil)
        sut.stop()

        wait(for: [completedEarly], timeout: 0.5)
    }
}
