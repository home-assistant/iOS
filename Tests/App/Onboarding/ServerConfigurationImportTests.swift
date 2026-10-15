import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct ServerConfigurationImportTests {
    // MARK: - Decoding + validation

    @Test func decodesAValidTwoServerFile() throws {
        let data = Data(Self.validFileJSON.utf8)
        let document = try ServerConfigurationImport.decode(data: data)

        #expect(document.kind == ServerConfigurationImport.fileKind)
        #expect(document.schemaVersion == 1)
        #expect(document.servers.count == 2)

        let withToken = document.servers[0]
        #expect(withToken.name == "Home")
        #expect(withToken.externalURL.absoluteString == "https://home.example.com")
        #expect(withToken.internalURL?.absoluteString == "http://homeassistant.local:8123")
        #expect(withToken.longLivedAccessToken == "home-token")
        #expect(withToken.isAutomatic)

        let withoutToken = document.servers[1]
        #expect(withoutToken.longLivedAccessToken == nil)
        #expect(withoutToken.internalURL == nil)
        #expect(!withoutToken.isAutomatic)
    }

    @Test func decodeTreatsMissingSchemaVersionAsV1() throws {
        let json = """
        { "kind": "home-assistant-servers",
          "servers": [ { "name": "Home", "externalURL": "https://ha.example.com" } ] }
        """
        let document = try ServerConfigurationImport.decode(data: Data(json.utf8))
        #expect(document.schemaVersion == 1)
        #expect(document.servers.count == 1)
    }

    @Test func decodeRejectsWrongKind() {
        let json = """
        { "kind": "something-else",
          "servers": [ { "name": "Home", "externalURL": "https://ha.example.com" } ] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .notAServerConfigurationFile = error { return true }
            return false
        }
    }

    @Test func decodeRejectsJSONThatIsNotAServerFile() {
        // Any other JSON document, e.g. one picked by mistake as plain `.json`, is rejected by kind.
        let json = """
        { "name": "package", "version": "1.0.0" }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .notAServerConfigurationFile(foundKind: nil) = error { return true }
            return false
        }
    }

    @Test func decodeRejectsNewerSchema() {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 99,
          "servers": [ { "name": "Home", "externalURL": "https://ha.example.com" } ] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .unsupportedSchema(99) = error { return true }
            return false
        }
    }

    @Test func decodeRejectsEmptyServerList() {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 1, "servers": [] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .noServers = error { return true }
            return false
        }
    }

    @Test func decodeRejectsAServerWithNoName() {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 1,
          "servers": [ { "name": "  ", "externalURL": "https://ha.example.com" } ] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .invalidServer(.missingName) = error { return true }
            return false
        }
    }

    @Test func decodeRejectsANonHTTPExternalURL() {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 1,
          "servers": [ { "name": "Home", "externalURL": "ftp://ha.example.com" } ] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .invalidServer(.invalidExternalURL) = error { return true }
            return false
        }
    }

    @Test func decodeRejectsGarbage() {
        expectImportError(Data("not json at all".utf8)) { error in
            if case .notReadable = error { return true }
            return false
        }
    }

    @Test func decodeRejectsAnInvalidInternalURL() {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 1,
          "servers": [ { "name": "Home", "externalURL": "https://ha.example.com", "internalURL": "not a url" } ] }
        """
        expectImportError(Data(json.utf8)) { error in
            if case .invalidServer(.invalidInternalURL("not a url")) = error { return true }
            return false
        }
    }

    @Test func everyImportErrorExplainsItself() {
        let errors: [ServerConfigurationImport.ImportError] = [
            .notReadable,
            .notAServerConfigurationFile(foundKind: "other"),
            .notAServerConfigurationFile(foundKind: nil),
            .unsupportedSchema(2),
            .noServers,
            .invalidServer(reason: .missingName),
            .invalidServer(reason: .invalidExternalURL("x")),
            .invalidServer(reason: .invalidInternalURL("y")),
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false, "\(error)")
        }

        let validationErrors: [HAServerTokenValidator.ValidationError] = [
            .notAnHTTPResponse, .unauthorized, .unexpectedStatus(500), .notHomeAssistant,
        ]
        for error in validationErrors {
            #expect(error.errorDescription?.isEmpty == false, "\(error)")
        }
    }

    @Test func onlyHassconfigFilesAreOpenedFromOutsideTheApp() {
        #expect(ServerConfigurationImport.externallyOpenableFileExtensions == ["hassconfig"])
        // The in-app picker still takes the same content saved as plain JSON.
        #expect(ServerConfigurationImport.acceptedFileExtensions.contains("json"))
    }

    @Test func onlyTheInboxCopyOfAnOpenedFileCountsAsDisposable() {
        let documents = URL(fileURLWithPath: "/tmp/container/Documents", isDirectory: true)
        #expect(ServerConfigurationImport.isInboxCopy(
            URL(fileURLWithPath: "/tmp/container/Documents/Inbox/servers.hassconfig"),
            documentsDirectory: documents
        ))
        // A file the in-app picker returned, elsewhere on the device, is the user's own.
        #expect(!ServerConfigurationImport.isInboxCopy(
            URL(fileURLWithPath: "/tmp/elsewhere/servers.hassconfig"),
            documentsDirectory: documents
        ))
        #expect(!ServerConfigurationImport.isInboxCopy(
            URL(fileURLWithPath: "/tmp/container/Documents/Inboxes/servers.hassconfig"),
            documentsDirectory: documents
        ))
    }

    // MARK: - Classification + dedupe

    @Test func classifyMarksTokenServersAutomaticAndTokenlessGuided() throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.validFileJSON.utf8))
        let outcomes = ServerConfigurationImport.classify(document, existingServers: [])

        #expect(outcomes[0].classification == .automatic)
        #expect(outcomes[1].classification == .guided)
    }

    @Test func classifyDedupesAgainstAnExistingExternalURL() throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.validFileJSON.utf8))
        // Same server, spelled with a trailing slash — must still match.
        let existing: [(name: String, externalURL: URL?)] = [
            (name: "My Home", externalURL: URL(string: "https://home.example.com/")!),
        ]
        let outcomes = ServerConfigurationImport.classify(document, existingServers: existing)

        #expect(outcomes[0].classification == .duplicate(existingName: "My Home"))
        // The token-less second server is unaffected.
        #expect(outcomes[1].classification == .guided)
    }

    @Test func classifyFlagsAURLTheFileListsTwice() throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.repeatedFileJSON.utf8))
        let outcomes = ServerConfigurationImport.classify(document, existingServers: [])

        #expect(outcomes.map(\.classification) == [
            .automatic,
            .repeatedInFile(firstName: "Home"),
            .guided,
            .repeatedInFile(firstName: "Cabin"),
        ])
    }

    @Test func normalizedKeyTreatsHTTPAndHTTPSDefaultPortsConsistently() {
        let withSlash = ServerConfigurationImport.normalizedKey(for: URL(string: "https://ha.example.com/")!)
        let withoutSlash = ServerConfigurationImport.normalizedKey(for: URL(string: "https://ha.example.com")!)
        #expect(withSlash == withoutSlash)

        let differentHost = ServerConfigurationImport.normalizedKey(for: URL(string: "https://other.example.com")!)
        #expect(withSlash != differentHost)
    }

    // MARK: - Runner (token path, with injected collaborators)

    @Test func runnerValidatesTokenAddsAndReportsAdded() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let validator = StubTokenValidator()
        let persistence = StubPersistence()
        let runner = ServerConfigurationImportRunner(tokenValidator: validator, persistence: persistence)

        let summary = await runner.run(document)

        #expect(summary.addedCount == 1)
        #expect(summary.guidedCount == 0)
        #expect(validator.validatedTokens == ["home-token"])
        #expect(persistence.added.map(\.name) == ["Home"])
    }

    @Test func runnerDoesNotAddAServerWhoseTokenFailsValidation() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let validator = StubTokenValidator(rejecting: ["home-token"])
        let persistence = StubPersistence()
        let runner = ServerConfigurationImportRunner(tokenValidator: validator, persistence: persistence)

        let summary = await runner.run(document)

        #expect(summary.addedCount == 0)
        #expect(summary.failedCount == 1)
        #expect(persistence.added.isEmpty)
    }

    @Test func runnerReportsAFailedSetupAsFailedNotAdded() async throws {
        // Registration (or any other setup step) failing means the server was not added.
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let persistence = StubPersistence(failingHosts: ["home.example.com"])
        let runner = ServerConfigurationImportRunner(tokenValidator: StubTokenValidator(), persistence: persistence)

        let summary = await runner.run(document)

        #expect(summary.addedCount == 0)
        #expect(summary.failedCount == 1)
        #expect(summary.outcomes[0].result == .failed(reason: "stub setup failed"))
        #expect(persistence.added.isEmpty)
    }

    @Test func runnerCollectsTokenlessServersForGuidedSignIn() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.validFileJSON.utf8))
        let runner = ServerConfigurationImportRunner(
            tokenValidator: StubTokenValidator(),
            persistence: StubPersistence()
        )

        let summary = await runner.run(document)

        #expect(summary.addedCount == 1)
        #expect(summary.guidedServers.map(\.name) == ["Cabin"])
    }

    @Test func runnerSkipsDuplicatesWithoutValidatingOrAdding() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let validator = StubTokenValidator()
        let persistence = StubPersistence(existing: [
            (name: "Existing", externalURL: URL(string: "https://home.example.com")!),
        ])
        let runner = ServerConfigurationImportRunner(tokenValidator: validator, persistence: persistence)

        let summary = await runner.run(document)

        #expect(summary.addedCount == 0)
        #expect(summary.skippedCount == 1)
        #expect(validator.validatedTokens.isEmpty)
        #expect(persistence.added.isEmpty)
    }

    @Test func runnerActsOnARepeatedURLOnlyOnce() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.repeatedFileJSON.utf8))
        let validator = StubTokenValidator()
        let persistence = StubPersistence()
        let runner = ServerConfigurationImportRunner(tokenValidator: validator, persistence: persistence)

        let summary = await runner.run(document)

        #expect(persistence.added.map(\.name) == ["Home"])
        #expect(validator.validatedTokens == ["home-token"])
        #expect(summary.guidedServers.map(\.name) == ["Cabin"])
        #expect(summary.addedCount == 1)
        #expect(summary.skippedCount == 2)
        #expect(summary.outcomes.map(\.result) == [
            .added,
            .skipped(reason: L10n.ImportServers.Skipped.repeatedInFile),
            .awaitingGuidedSignIn,
            .skipped(reason: L10n.ImportServers.Skipped.repeatedInFile),
        ])
    }

    @Test func runnerGivesARepeatedURLItsOwnAttemptWhenTheFirstFailed() async throws {
        let json = """
        { "kind": "home-assistant-servers", "schemaVersion": 1, "servers": [
          { "name": "Home", "externalURL": "https://home.example.com", "longLivedAccessToken": "stale" },
          { "name": "Home again", "externalURL": "https://home.example.com/", "longLivedAccessToken": "fresh" }
        ] }
        """
        let document = try ServerConfigurationImport.decode(data: Data(json.utf8))
        let validator = StubTokenValidator(rejecting: ["stale"])
        let persistence = StubPersistence()
        let runner = ServerConfigurationImportRunner(tokenValidator: validator, persistence: persistence)

        let summary = await runner.run(document)

        #expect(validator.validatedTokens == ["stale", "fresh"])
        #expect(persistence.added.map(\.name) == ["Home again"])
        #expect(summary.addedCount == 1)
        #expect(summary.failedCount == 1)
    }

    @Test func runnerWritesNothingOnceCancelled() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.validFileJSON.utf8))
        let gate = ValidationGate()
        let persistence = StubPersistence()
        let runner = ServerConfigurationImportRunner(tokenValidator: gate, persistence: persistence)

        let task = Task {
            await runner.run(document)
        }
        // Cancel while the first token is being checked, then let the check answer.
        try await gate.waitUntilValidating()
        task.cancel()
        gate.open()
        let summary = await task.value

        #expect(persistence.added.isEmpty)
        #expect(summary.addedCount == 0)
        #expect(summary.guidedServers.isEmpty)
        #expect(summary.outcomes.map(\.result) == [
            .skipped(reason: L10n.ImportServers.Skipped.cancelled),
            .skipped(reason: L10n.ImportServers.Skipped.cancelled),
        ])
    }

    // MARK: - Token validator

    @Test func validatorRequestsTheAPIEndpointWithItsTrailingSlash() async throws {
        #expect(
            HAServerTokenValidator.apiURL(for: URL(string: "https://home.example.com")!)
                .absoluteString == "https://home.example.com/api/"
        )
        #expect(
            HAServerTokenValidator.apiURL(for: URL(string: "https://home.example.com/")!)
                .absoluteString == "https://home.example.com/api/"
        )

        let recorder = RequestRecorder()
        var validator = HAServerTokenValidator()
        validator.load = { request in
            recorder.requests.append(request)
            let response: URLResponse = Self.response(status: 200, for: request)
            return (Data(#"{"message": "API running."}"#.utf8), response)
        }

        try await validator.validate(token: "home-token", externalURL: URL(string: "https://home.example.com")!)

        #expect(recorder.requests.map(\.url?.absoluteString) == ["https://home.example.com/api/"])
        #expect(recorder.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer home-token")
    }

    @Test func validatorAcceptsHomeAssistantsAPIRunningResponse() throws {
        try HAServerTokenValidator.evaluate(
            data: Data(#"{"message":"API running."}"#.utf8),
            response: Self.response(status: 200)
        )
    }

    @Test func validatorRejectsAnHTMLLoginPageServedWith200() {
        expectValidationError(.notHomeAssistant) {
            try HAServerTokenValidator.evaluate(
                data: Data("<html><body><form>Sign in to continue</form></body></html>".utf8),
                response: Self.response(status: 200, contentType: "text/html")
            )
        }
    }

    @Test func validatorRejectsOtherJSONServedWith200() {
        expectValidationError(.notHomeAssistant) {
            try HAServerTokenValidator.evaluate(
                data: Data(#"{"status":"ok"}"#.utf8),
                response: Self.response(status: 200)
            )
        }
    }

    @Test func validatorRejectsAnEmptyNoContentResponse() {
        expectValidationError(.unexpectedStatus(204)) {
            try HAServerTokenValidator.evaluate(data: Data(), response: Self.response(status: 204))
        }
    }

    @Test func validatorRejectsOtherSuccessStatuses() {
        expectValidationError(.unexpectedStatus(202)) {
            try HAServerTokenValidator.evaluate(
                data: Data(#"{"message":"API running."}"#.utf8),
                response: Self.response(status: 202)
            )
        }
    }

    @Test func validatorRejectsAResponseThatIsNotHTTP() {
        expectValidationError(.notAnHTTPResponse) {
            try HAServerTokenValidator.evaluate(
                data: Data(),
                response: URLResponse(
                    url: URL(string: "https://home.example.com/api/")!,
                    mimeType: nil,
                    expectedContentLength: 0,
                    textEncodingName: nil
                )
            )
        }
    }

    @Test func validatorFailsForAServerThatCannotBeReached() async {
        // Nothing listens on the discard port, so the live request fails without a network.
        let validator = HAServerTokenValidator(timeout: 5)
        await #expect(throws: (any Error).self) {
            try await validator.validate(token: "home-token", externalURL: URL(string: "http://127.0.0.1:9")!)
        }
    }

    @Test func validatorReportsARejectedToken() {
        expectValidationError(.unauthorized) {
            try HAServerTokenValidator.evaluate(
                data: Data("401: Unauthorized".utf8),
                response: Self.response(status: 401)
            )
        }
    }

    // MARK: - Live persistence

    @Test func livePersistenceDedupesAgainstTheConfiguredServers() {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        let existing = LiveServerConfigurationPersistence().existingServers

        #expect(existing.map(\.name) == [server.info.name])
        #expect(existing.map(\.externalURL) == [server.info.connection.urlForTroubleshooting(type: .external)])
    }

    // MARK: - ServerInfo construction

    @Test func makeServerInfoBuildsTheServerSetupStartsFrom() throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.validFileJSON.utf8))
        let entry = document.servers[0]
        let info = LiveServerConfigurationPersistence.makeServerInfo(entry: entry, token: "home-token")

        #expect(info.name == "Home")
        // Kept as the local name so the server's own name from `get_config` doesn't replace it.
        #expect(info.setting(for: .localName) == "Home")
        #expect(info.token.accessToken == "home-token")
        #expect(info.token.refreshToken == "")
        #expect(info.token.expiration == .distantFuture)
        // Filled in by mobile app registration before anything is persisted.
        #expect(info.connection.webhookID == "")
        #expect(info.connection.urlForTroubleshooting(type: .external)?.absoluteString == "https://home.example.com")
        #expect(
            info.connection.urlForTroubleshooting(type: .internal)?
                .absoluteString == "http://homeassistant.local:8123"
        )
    }

    // MARK: - Guided sign-in chaining

    @MainActor
    @Test func guidedSignInWalksThroughEveryServerInOrder() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.twoGuidedFileJSON.utf8))
        let presenter = RecordingSignInPresenter()
        var outcome: ServerConfigurationGuidedSignIn.Outcome?

        let chain = ServerConfigurationGuidedSignIn(servers: document.servers, present: presenter.present)
        chain.onFinished = { outcome = $0 }

        chain.start()
        // First server presented immediately; nothing else until its flow completes and goes away.
        #expect(presenter.presentedURLs == ["https://ha.one.example"])

        Current.onboardingObservation.complete()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(presenter.presentedURLs.count == 1)

        presenter.dismissCurrent()
        #expect(presenter.presentedURLs == ["https://ha.one.example", "https://ha.two.example"])
        #expect(outcome == nil)

        Current.onboardingObservation.complete()
        try await Task.sleep(nanoseconds: 50_000_000)
        presenter.dismissCurrent()
        #expect(presenter.presentedURLs.count == 2)
        #expect(outcome == .completed)

        // A later stray completion must not present anything more.
        Current.onboardingObservation.complete()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(presenter.presentedURLs.count == 2)
    }

    @MainActor
    @Test func guidedSignInDropsTheQueueWhenAFlowIsCancelled() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.twoGuidedFileJSON.utf8))
        let presenter = RecordingSignInPresenter()
        var outcome: ServerConfigurationGuidedSignIn.Outcome?

        let chain = ServerConfigurationGuidedSignIn(servers: document.servers, present: presenter.present)
        chain.onFinished = { outcome = $0 }
        chain.start()

        // The user closes the first sign-in without finishing it.
        presenter.dismissCurrent()
        #expect(outcome == .abandoned)
        #expect(presenter.presentedURLs == ["https://ha.one.example"])

        // An unrelated onboarding finishing later must not resume the abandoned import.
        Current.onboardingObservation.complete()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(presenter.presentedURLs == ["https://ha.one.example"])
    }

    @MainActor
    @Test func guidedSignInReleasesItselfWhenAbandoned() throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.twoGuidedFileJSON.utf8))
        let presenter = RecordingSignInPresenter()
        weak var weakChain: ServerConfigurationGuidedSignIn?

        // Registering with the observation table hands the chain to Objective-C, which can leave it in
        // the autorelease pool; drain it so only the chain's own references are measured.
        autoreleasepool {
            let chain = ServerConfigurationGuidedSignIn(servers: document.servers, present: presenter.present)
            weakChain = chain
            chain.start()
        }
        #expect(weakChain != nil)

        autoreleasepool {
            presenter.dismissCurrent()
        }
        #expect(weakChain == nil)
    }

    @MainActor
    @Test func guidedSignInFinishesImmediatelyWhenEmpty() {
        let presenter = RecordingSignInPresenter()
        var outcome: ServerConfigurationGuidedSignIn.Outcome?
        let chain = ServerConfigurationGuidedSignIn(servers: [], present: presenter.present)
        chain.onFinished = { outcome = $0 }
        chain.start()
        #expect(presenter.presentedURLs.isEmpty)
        #expect(outcome == .completed)
    }

    // MARK: - Confirmation / results screen

    @MainActor
    @Test func resultsStayOnScreenUntilTheUserContinuesToSignIn() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.mixedFileJSON.utf8))
        let viewModel = ServerConfigurationImportViewModel(
            document: document,
            runner: ServerConfigurationImportRunner(
                tokenValidator: StubTokenValidator(rejecting: ["bad-token"]),
                persistence: StubPersistence()
            )
        )
        var dismissRequests = 0
        var completions: [ServerConfigurationImportViewModel.Completion] = []
        viewModel.onRequestDismiss = { dismissRequests += 1 }
        viewModel.onCompletion = { completions.append($0) }

        viewModel.confirm()
        #expect(viewModel.isImporting)
        try await waitUntilFinished(viewModel)

        // The mixed results (an addition, a failure, a pending sign-in) are shown; nothing has been
        // dismissed or started on its own.
        #expect(viewModel.phase == .finished(.init(added: 1, skipped: 0, failed: 1, guidedRemaining: 1)))
        #expect(dismissRequests == 0)
        #expect(completions.isEmpty)

        viewModel.continueToGuidedSignIn()
        #expect(dismissRequests == 1)
        #expect(completions.isEmpty)

        viewModel.didDismiss()
        #expect(completions.map { $0.guidedServers.map(\.name) } == [["Cabin"]])
        // No server existed before and one was added, so the first-run onboarding is over.
        #expect(completions.first?.completesFirstRun == true)
    }

    @MainActor
    @Test func closingTheResultsDoesNotStartSignIn() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.mixedFileJSON.utf8))
        let viewModel = ServerConfigurationImportViewModel(
            document: document,
            runner: ServerConfigurationImportRunner(
                tokenValidator: StubTokenValidator(),
                persistence: StubPersistence(existing: [
                    (name: "Elsewhere", externalURL: URL(string: "https://elsewhere.example.com")!),
                ])
            )
        )
        var completions: [ServerConfigurationImportViewModel.Completion] = []
        viewModel.onCompletion = { completions.append($0) }

        viewModel.confirm()
        try await waitUntilFinished(viewModel)
        viewModel.close()
        viewModel.didDismiss()

        // Servers already existed, so finishing first-run onboarding would wrongly switch servers.
        #expect(completions == [.init(guidedServers: [], completesFirstRun: false)])
    }

    @MainActor
    @Test func theScreenCannotBeClosedWhileImporting() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let gate = ValidationGate()
        let viewModel = ServerConfigurationImportViewModel(
            document: document,
            runner: ServerConfigurationImportRunner(tokenValidator: gate, persistence: StubPersistence())
        )
        var dismissRequests = 0
        viewModel.onRequestDismiss = { dismissRequests += 1 }

        viewModel.confirm()
        viewModel.close()
        #expect(dismissRequests == 0)
        #expect(viewModel.isImporting)

        gate.open()
        try await waitUntilFinished(viewModel)
    }

    @MainActor
    @Test func dismissalMidImportStopsBeforeAnythingIsWritten() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.tokenOnlyFileJSON.utf8))
        let gate = ValidationGate()
        let persistence = StubPersistence()
        let viewModel = ServerConfigurationImportViewModel(
            document: document,
            runner: ServerConfigurationImportRunner(tokenValidator: gate, persistence: persistence)
        )
        var completions: [ServerConfigurationImportViewModel.Completion] = []
        viewModel.onCompletion = { completions.append($0) }

        viewModel.confirm()
        try await gate.waitUntilValidating()
        // Something else clears the screen while the token is being checked.
        viewModel.didDismiss()
        gate.open()
        try await waitUntilFinished(viewModel)

        #expect(persistence.added.isEmpty)
        #expect(completions == [.init(guidedServers: [], completesFirstRun: false)])
    }

    // MARK: - Helpers

    @MainActor
    private func waitUntilFinished(_ viewModel: ServerConfigurationImportViewModel) async throws {
        for _ in 0 ..< 200 {
            if case .finished = viewModel.phase { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Import did not finish")
    }

    private func expectImportError(
        _ data: Data,
        _ predicate: (ServerConfigurationImport.ImportError) -> Bool
    ) {
        do {
            _ = try ServerConfigurationImport.decode(data: data)
            Issue.record("Expected decode to throw")
        } catch let error as ServerConfigurationImport.ImportError {
            #expect(predicate(error), "Unexpected ImportError: \(error)")
        } catch {
            Issue.record("Expected ImportError, got \(error)")
        }
    }

    private func expectValidationError(
        _ expected: HAServerTokenValidator.ValidationError,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            Issue.record("Expected validation to throw \(expected)")
        } catch {
            #expect(error as? HAServerTokenValidator.ValidationError == expected)
        }
    }

    private static func response(
        status: Int,
        contentType: String = "application/json",
        for request: URLRequest? = nil
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request?.url ?? URL(string: "https://home.example.com/api/")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
    }

    private static let validFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        {
          "name": "Home",
          "externalURL": "https://home.example.com",
          "internalURL": "http://homeassistant.local:8123",
          "longLivedAccessToken": "home-token"
        },
        {
          "name": "Cabin",
          "externalURL": "https://cabin.example.com"
        }
      ]
    }
    """

    private static let mixedFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        { "name": "Home", "externalURL": "https://home.example.com", "longLivedAccessToken": "home-token" },
        { "name": "Office", "externalURL": "https://office.example.com", "longLivedAccessToken": "bad-token" },
        { "name": "Cabin", "externalURL": "https://cabin.example.com" }
      ]
    }
    """

    private static let repeatedFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        { "name": "Home", "externalURL": "https://home.example.com", "longLivedAccessToken": "home-token" },
        { "name": "Home again", "externalURL": "https://HOME.example.com/", "longLivedAccessToken": "home-token" },
        { "name": "Cabin", "externalURL": "https://cabin.example.com" },
        { "name": "Cabin again", "externalURL": "https://cabin.example.com" }
      ]
    }
    """

    private static let twoGuidedFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        { "name": "One", "externalURL": "https://ha.one.example" },
        { "name": "Two", "externalURL": "https://ha.two.example" }
      ]
    }
    """

    private static let tokenOnlyFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        {
          "name": "Home",
          "externalURL": "https://home.example.com",
          "longLivedAccessToken": "home-token"
        }
      ]
    }
    """
}

// MARK: - Stubs

private final class StubTokenValidator: ServerTokenValidating, @unchecked Sendable {
    let rejectedTokens: Set<String>
    private(set) var validatedTokens: [String] = []

    init(rejecting rejectedTokens: Set<String> = []) {
        self.rejectedTokens = rejectedTokens
    }

    struct StubError: LocalizedError {
        var errorDescription: String? { "stub rejected token" }
    }

    func validate(token: String, externalURL: URL) async throws {
        validatedTokens.append(token)
        if rejectedTokens.contains(token) {
            throw StubError()
        }
    }
}

/// Holds token validation until the test opens it, so a test can act while the import is running.
private final class ValidationGate: ServerTokenValidating, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    private var validationsStarted = 0

    func open() {
        let waiting = lock.withLock {
            isOpen = true
            defer { continuations.removeAll() }
            return continuations
        }
        waiting.forEach { $0.resume() }
    }

    /// Returns once a validation is waiting on the gate.
    func waitUntilValidating() async throws {
        for _ in 0 ..< 200 {
            if lock.withLock({ validationsStarted > 0 }) { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Validation never started")
    }

    func validate(token: String, externalURL: URL) async throws {
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock {
                validationsStarted += 1
                if !isOpen {
                    continuations.append(continuation)
                }
                return isOpen
            }
            if resumeNow {
                continuation.resume()
            }
        }
    }
}

private final class StubPersistence: ServerConfigurationPersisting, @unchecked Sendable {
    let existingServers: [(name: String, externalURL: URL?)]
    let failingHosts: Set<String>
    private(set) var added: [ServerConfigurationImport.ServerEntry] = []

    init(existing: [(name: String, externalURL: URL?)] = [], failingHosts: Set<String> = []) {
        self.existingServers = existing
        self.failingHosts = failingHosts
    }

    struct StubError: LocalizedError {
        var errorDescription: String? { "stub setup failed" }
    }

    @discardableResult
    func add(entry: ServerConfigurationImport.ServerEntry, token: String) async throws -> Identifier<Server> {
        if let host = entry.externalURL.host, failingHosts.contains(host) {
            throw StubError()
        }
        added.append(entry)
        return Identifier<Server>(rawValue: "stub-\(added.count)")
    }
}

private final class RequestRecorder: @unchecked Sendable {
    var requests: [URLRequest] = []
}

@MainActor
private final class RecordingSignInPresenter {
    private(set) var presentedURLs: [String] = []
    private var pendingDismissal: (() -> Void)?

    func present(_ url: URL, onDismissed: @escaping () -> Void) {
        presentedURLs.append(url.absoluteString)
        pendingDismissal = onDismissed
    }

    /// The flow on screen goes away, by finishing or by the user closing it.
    func dismissCurrent() {
        let dismissal = pendingDismissal
        pendingDismissal = nil
        dismissal?()
    }
}
