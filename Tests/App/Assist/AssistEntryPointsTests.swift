@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import XCTest

/// Every way into Assist funnels through `showAssist`, which hands a running session its new context
/// rather than presenting a second one.
final class AssistEntryPointsTests: XCTestCase {
    private final class SessionDelegate: AssistSessionDelegate {
        var contexts: [AssistSessionContext] = []
        var onContext: (() -> Void)?

        func didRequestNewSession(_ context: AssistSessionContext) {
            contexts.append(context)
            onContext?()
        }
    }

    private var delegate: SessionDelegate!
    private var previousServers: ServerManager!
    private var servers: FakeServerManager!
    private var server: Server!

    @MainActor
    override func setUp() async throws {
        delegate = SessionDelegate()
        AssistSession.shared.delegate = delegate
        AssistSession.shared.inProgress = true

        previousServers = Current.servers
        servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers
    }

    /// `webView` is created in `viewDidLoad`, and an unloaded controller handed to the scene manager
    /// trips over it the next time something asks it to refresh.
    @MainActor
    private func makeWebViewController() -> WebViewController {
        let controller = WebViewController(server: server)
        controller.loadViewIfNeeded()
        return controller
    }

    @MainActor
    override func tearDown() async throws {
        AssistSession.shared.delegate = nil
        AssistSession.shared.inProgress = false
        Current.servers = previousServers
        previousServers = nil
        servers = nil
        server = nil
        delegate = nil
    }

    @MainActor
    func testShowAssistHandsARunningSessionTheNewContext() {
        // `webViewController` is weak, so the mock has to outlive the call.
        let webViewController = MockWebViewController()
        let handler = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
        handler.webViewController = webViewController

        handler.showAssist(server: server, pipeline: "pipeline-1", autoStartRecording: true)

        XCTAssertEqual(delegate.contexts.count, 1)
        XCTAssertEqual(delegate.contexts.first?.server.identifier, server.identifier)
        XCTAssertEqual(delegate.contexts.first?.pipelineId, "pipeline-1")
        XCTAssertEqual(delegate.contexts.first?.autoStartRecording, true)
    }

    @MainActor
    func testTabBarAssistButtonOpensAssistForItsServer() {
        let webViewController = makeWebViewController()
        let viewModel = HomeAssistantViewModel(server: server)
        viewModel.webViewController = webViewController

        viewModel.tabBar.onAssist?(nil)

        XCTAssertEqual(delegate.contexts.count, 1)
        XCTAssertEqual(delegate.contexts.first?.server.identifier, server.identifier)
        XCTAssertEqual(delegate.contexts.first?.pipelineId, "")
        XCTAssertEqual(delegate.contexts.first?.autoStartRecording, false)

        withExtendedLifetime((webViewController, viewModel)) {}
    }

    @available(iOS 18, *)
    @MainActor
    func testAssistAppIntentOpensAssistForItsPipeline() {
        Current.sceneManager.setWebViewController(makeWebViewController())

        let requested = expectation(description: "session requested")
        delegate.onContext = { requested.fulfill() }

        AssistAppIntent.openAssist(
            serverId: server.identifier.rawValue,
            pipelineId: "pipeline-3",
            withVoice: false
        )
        wait(for: [requested], timeout: 30)

        XCTAssertEqual(delegate.contexts.first?.server.identifier, server.identifier)
        XCTAssertEqual(delegate.contexts.first?.pipelineId, "pipeline-3")
        XCTAssertEqual(delegate.contexts.first?.autoStartRecording, false)
    }

    @MainActor
    func testAssistDeeplinkOpensAssistWithItsQueryParameters() throws {
        let handler = IncomingURLHandler(coordinator: MockAppCoordinator())
        Current.sceneManager.setWebViewController(makeWebViewController())

        let url = try XCTUnwrap(URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)assist/?serverId=\(server.identifier.rawValue)"
                + "&pipelineId=pipeline-2&startListening=true"
        ))

        let requested = expectation(description: "session requested")
        delegate.onContext = { requested.fulfill() }

        XCTAssertTrue(handler.handle(url: url))
        wait(for: [requested], timeout: 30)

        XCTAssertEqual(delegate.contexts.first?.server.identifier, server.identifier)
        XCTAssertEqual(delegate.contexts.first?.pipelineId, "pipeline-2")
        XCTAssertEqual(delegate.contexts.first?.autoStartRecording, true)
    }
}
