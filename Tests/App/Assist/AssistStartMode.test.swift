@testable import HomeAssistant
import Shared
import Testing

struct AssistStartModeTests {
    @Test func autoFollowsFrontendRequest() {
        #expect(AssistStartMode.auto.resolveAutoStartRecording(frontendRequested: true))
        #expect(AssistStartMode.auto.resolveAutoStartRecording(frontendRequested: false) == false)
    }

    @Test func voiceAlwaysStartsRecording() {
        #expect(AssistStartMode.voice.resolveAutoStartRecording(frontendRequested: true))
        #expect(AssistStartMode.voice.resolveAutoStartRecording(frontendRequested: false))
    }

    @Test func textNeverStartsRecording() {
        #expect(AssistStartMode.text.resolveAutoStartRecording(frontendRequested: true) == false)
        #expect(AssistStartMode.text.resolveAutoStartRecording(frontendRequested: false) == false)
    }

    @Test func defaultConfigurationUsesAuto() {
        #expect(AssistConfiguration().startMode == .auto)
    }

    @Test func eachModeHasItsOwnTitle() {
        let titles = AssistStartMode.allCases.map(\.localizedTitle)
        #expect(Set(titles).count == AssistStartMode.allCases.count)
    }
}
