@testable import HomeAssistant
import Testing
import WebKit

struct CatalystTimeInputWorkaroundTests {
    @Test func userScriptRunsInEveryFrameBeforeThePageLoads() {
        let script = CatalystTimeInputWorkaround.userScript

        #expect(!script.isForMainFrameOnly)
        #expect(script.injectionTime == .atDocumentStart)
    }

    @Test func userScriptOnlyTargetsTimeInputs() {
        let source = CatalystTimeInputWorkaround.userScript.source

        #expect(source.contains("element.type === \"time\""))
        #expect(!source.contains("datetime-local"))
    }
}
