@testable import HomeAssistant
@testable import Shared
import Testing

struct AssistServiceFetchPipelinesTests {
    /// A server with no usable URL has no API to ask, so the fetch has to finish right away instead
    /// of never calling back — callers waiting on every server would otherwise wait forever.
    @Test func serverWithoutUsableURLCompletesWithNil() {
        let server = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        var completed = false
        var response: PipelineResponse?

        AssistService(server: server).fetchPipelines {
            completed = true
            response = $0
        }

        #expect(completed)
        #expect(response == nil)
    }
}
