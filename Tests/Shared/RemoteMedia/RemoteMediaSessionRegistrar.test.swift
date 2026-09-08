import Foundation
@testable import Shared
import Testing

/// How the extension offers its push token, exercised through the registrar the extension actually
/// uses so the behaviour under test is the composed one rather than the ledger's in isolation.
@MainActor
struct RemoteMediaSessionRegistrarTests {
    private static let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")

    private static let context = RemoteMediaTransportContext(
        selection: selection,
        webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
        secret: nil
    )

    /// Records every registration the sender was given, and answers with whatever is queued.
    private final class Server: @unchecked Sendable {
        private let lock = NSLock()
        private var _registrations: [RemoteMediaSessionRegistration] = []
        private var _failures: [Error?] = []

        var registrations: [RemoteMediaSessionRegistration] {
            lock.lock(); defer { lock.unlock() }
            return _registrations
        }

        /// One entry per attempt: `nil` accepts, an error rejects. Runs out into acceptance.
        func failing(with failures: [Error?]) -> Self {
            lock.lock(); defer { lock.unlock() }
            _failures = failures
            return self
        }

        var perform: RemoteMediaRegistrationSender.Perform {
            { [self] registration, _ in
                lock.lock()
                _registrations.append(registration)
                var failure: Error?
                if !_failures.isEmpty { failure = _failures.removeFirst() }
                lock.unlock()
                if let failure { throw failure }
            }
        }
    }

    /// A representation: what the extension builds once per launch, with its own runtime ledger.
    private func representation(
        _ server: Server,
        retryDelays: [Duration] = []
    ) -> RemoteMediaSessionRegistrar {
        .init(sender: .init(retryDelays: retryDelays, perform: server.perform))
    }

    private func offer(
        _ registrar: RemoteMediaSessionRegistrar,
        token: [UInt8],
        context: RemoteMediaTransportContext? = RemoteMediaSessionRegistrarTests.context
    ) {
        registrar.offer(
            token: .init(Data(token)),
            sessionId: Self.selection.id,
            serverId: Self.selection.serverId,
            entityId: Self.selection.entityId,
            context: context
        )
    }

    /// Registration is one POST, not a poll: nothing here waits on a clock, so a short settle is
    /// all that is needed for the sender's task to have run.
    private func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    /// Settles until `condition` holds, for the assertions that count requests.
    ///
    /// A fixed number of yields is enough when this suite has the process to itself and not when
    /// it is sharing it: the send is a detached task, and observing it late reads as the request
    /// never having been made. Bounded, so a genuine failure still fails rather than hanging.
    private func settle(until condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
    }

    // MARK: - Dedupe

    @Test func theSameTokenSeenRepeatedlyIsRegisteredOnce() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        for _ in 0 ..< 5 {
            offer(registrar, token: [0x01, 0x02])
        }
        await settle()
        #expect(server.registrations.count == 1)
        #expect(server.registrations.first?.pushToken == "0102")
    }

    /// Every extension launch is a fresh chance for a Home Assistant that has since been upgraded
    /// to learn the token, so "already offered" must not outlive the representation that offered it.
    @Test func aNewRepresentationOffersTheSameRegistrationAgain() async {
        let server = Server()
        let first = representation(server)
        first.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(first, token: [0x01, 0x02])
        await settle()

        // Same session, same lifetime, same token — the extension was simply launched again.
        let second = representation(server)
        second.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(second, token: [0x01, 0x02])
        await settle()

        #expect(server.registrations.count == 2)
        #expect(server.registrations[0] == server.registrations[1])
    }

    // MARK: - Rotation

    @Test func aReplacementTokenIsRegisteredForTheSameLifetime() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        await settle()
        offer(registrar, token: [0x02])
        await settle()

        #expect(server.registrations.map(\.pushToken) == ["01", "02"])
        // The lifetime and the session are unchanged: this supersedes rather than starting over.
        #expect(server.registrations.allSatisfy { $0.generation == "A" })
        #expect(Set(server.registrations.map(\.sessionId)).count == 1)
    }

    /// Following the same player again reuses the session identifier, so an unchanged token still
    /// has to be registered against the new lifetime.
    @Test func anUnchangedTokenIsRegisteredAgainForANewLifetime() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x07])
        await settle()
        registrar.adopt(lifetime: .init(generation: "B", sequence: 11))
        offer(registrar, token: [0x07])
        await settle()

        #expect(server.registrations.map(\.generation) == ["A", "B"])
        // And the later relationship is recognisably later, which is what the server orders by.
        #expect(server.registrations.map(\.generationSequence) == [10, 11])
    }

    /// Attributes from a build that predates ordered relationships describe none. Registering then
    /// would hand the server a token it could not place in time, so nothing is sent and the user
    /// has to follow again.
    @Test func anUnorderedRelationshipRegistersNothing() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: nil)
        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.isEmpty)

        // Following again gives it an order, and the token goes out.
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.count == 1)
    }

    // MARK: - Stale generations

    /// A token observed late still belongs to the session, so it is registered against whichever
    /// lifetime is current rather than the one that was current when the framework produced it.
    /// This is why nothing here compares generations for order: they are identities.
    @Test func anOfferCarriesTheLifetimeThatIsCurrentWhenItIsMade() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        registrar.adopt(lifetime: .init(generation: "B", sequence: 11))
        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.map(\.generation) == ["B"])
    }

    /// A registration still in flight when the user stops following describes a relationship that
    /// is over, so adopting the next lifetime abandons it instead of letting it finish.
    @Test func adoptingANewLifetimeAbandonsWhatWasInFlightForTheLast() async throws {
        let server = Server().failing(with: [URLError(.timedOut)])
        let registrar = representation(server, retryDelays: [.milliseconds(80)])
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.count == 1)

        registrar.adopt(lifetime: .init(generation: "B", sequence: 11))
        try await Task.sleep(for: .milliseconds(200))
        // A's retry never went out, and adopting B did not itself register anything: the token is
        // offered again by the next update, under B.
        #expect(server.registrations.count == 1)
        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(100))
        #expect(server.registrations.map(\.generation) == ["A", "B"])
    }

    /// A registration waiting to retry when its lifetime ends is abandoned rather than handed to
    /// the server late. Generations are identities, so this is decided by equality with the current
    /// one — never by which came first.
    @Test func aRetryIsAbandonedWhenItsLifetimeEnds() async throws {
        let server = Server().failing(with: [URLError(.notConnectedToInternet)])
        let registrar = representation(server, retryDelays: [.milliseconds(50)])
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.count == 1)

        // Stop following and follow again before the retry is due.
        registrar.adopt(lifetime: .init(generation: "B", sequence: 11))
        try await Task.sleep(for: .milliseconds(150))
        // Only the first attempt, which was already out when the lifetime ended.
        #expect(server.registrations.count == 1)
        #expect(server.registrations.first?.generation == "A")
    }

    // MARK: - Transport failure

    @Test func anUnreachableServerIsRetriedWithinABudget() async throws {
        let server = Server().failing(with: [
            URLError(.timedOut),
            URLError(.timedOut),
            nil,
        ])
        let registrar = representation(server, retryDelays: [.milliseconds(10), .milliseconds(10)])
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(200))
        #expect(server.registrations.count == 3)
    }

    @Test func theBudgetIsSpentRatherThanRetriedForever() async throws {
        let server = Server().failing(with: Array(repeating: URLError(.timedOut), count: 20))
        let registrar = representation(server, retryDelays: [.milliseconds(10), .milliseconds(10)])
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(300))
        #expect(server.registrations.count == 3)
    }

    /// A token that never reached anyone is still owed, and the host app publishing the next state
    /// change is a free chance to try again — no timer, no wake-up of our own.
    @Test func aTokenThatNeverArrivedIsOfferedAgainOnTheNextUpdate() async throws {
        let server = Server().failing(with: [URLError(.cannotConnectToHost)])
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(100))
        #expect(server.registrations.count == 1)

        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(100))
        #expect(server.registrations.count == 2)
    }

    /// A server that read the request and refused it will refuse it again, so the offer stands and
    /// every following state change does not become another POST.
    @Test func aRefusalIsNotRepeatedOnEveryUpdate() async throws {
        let server = Server().failing(with: [
            RemoteMediaWebhookClient.ClientError.unacceptableStatus(code: 404),
        ])
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01])
        try await Task.sleep(for: .milliseconds(100))
        for _ in 0 ..< 5 {
            offer(registrar, token: [0x01])
        }
        try await Task.sleep(for: .milliseconds(100))
        #expect(server.registrations.count == 1)
    }

    /// The routes and the secret are written by the host app, so a token can arrive before them.
    @Test func aMissingTransportContextLeavesTheTokenOwed() async {
        let server = Server()
        let registrar = representation(server)
        registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(registrar, token: [0x01], context: nil)
        await settle()
        #expect(server.registrations.isEmpty)

        offer(registrar, token: [0x01])
        await settle()
        #expect(server.registrations.count == 1)
    }

    // MARK: - Older Home Assistant

    /// A Home Assistant without the matching Core support answers an unknown webhook type with an
    /// empty 200. That must be silent, must change nothing about the local session, and must not be
    /// remembered as the server having registered anything — the offer is repeated by the next
    /// representation so an upgraded server eventually learns it.
    @Test func anOlderHomeAssistantAnswersEmptilyAndNothingIsRemembered() async throws {
        let empty = EmptyOkayServer()
        let first = RemoteMediaSessionRegistrar(
            sender: .init(retryDelays: [], perform: empty.perform)
        )
        first.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(first, token: [0x01])
        await settle(until: { empty.requests.count >= 1 })
        #expect(empty.requests.count == 1)
        #expect(empty.bodies.allSatisfy { $0["type"] as? String == "remote_media_session_token" })

        // Home Assistant is upgraded. Nothing had to be forgotten first.
        let second = RemoteMediaSessionRegistrar(
            sender: .init(retryDelays: [], perform: empty.perform)
        )
        second.adopt(lifetime: .init(generation: "A", sequence: 10))
        offer(second, token: [0x01])
        await settle(until: { empty.requests.count >= 2 })
        #expect(empty.requests.count == 2)
    }

    /// Answers every request the way `mobile_app` answers a webhook type it does not know.
    private final class EmptyOkayServer: @unchecked Sendable {
        private let lock = NSLock()
        var requests: [URLRequest] = []
        var bodies: [[String: Any]] = []

        var perform: RemoteMediaRegistrationSender.Perform {
            { [self] registration, context in
                let client = RemoteMediaWebhookClient { request in
                    lock.lock()
                    requests.append(request)
                    if let body = request.httpBody,
                       let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                        bodies.append(object)
                    }
                    lock.unlock()
                    let response = HTTPURLResponse(
                        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
                    )!
                    return (Data("{}".utf8), response)
                }
                try await client.register(registration, context: context)
            }
        }
    }

    // MARK: - Reconciling with a server that did not keep it

    /// A request lives in the App Group the running app shares, so each of these gets its own
    /// domain: otherwise one test's request is another's, and every registrar in the process reads
    /// the same counter.
    private func isolatedReoffers<T>(_ body: () async -> T) async -> T {
        let name = "RemoteMediaSessionRegistrarTests.\(UUID().uuidString)"
        let previous = RemoteMediaReofferSignal.defaults
        RemoteMediaReofferSignal.defaults = UserDefaults(suiteName: name)
        let result = await body()
        UserDefaults().removePersistentDomain(forName: name)
        RemoteMediaReofferSignal.defaults = previous
        return result
    }

    /// The reported failure: a player followed the previous day, a Home Assistant with no record of
    /// it, and an extension whose ledger says it has already registered. Nothing about the
    /// relationship changed, so nothing re-offered it, and only stopping and following again did.
    @Test func aHostAppRequestOffersTheSameRegistrationAgain() async {
        await isolatedReoffers {
            let server = Server()
            let registrar = representation(server)
            registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
            offer(registrar, token: [0x01, 0x02])
            await settle()
            #expect(server.registrations.count == 1)

            // The host app launched, or a server reconnected, and cannot tell whether Home Assistant
            // still holds the relationship.
            RemoteMediaReofferSignal.request()
            offer(registrar, token: [0x01, 0x02])
            await settle()

            #expect(server.registrations.count == 2)
        }
    }

    /// The invariant that makes re-offering safe: it is the same relationship, so Home Assistant
    /// sees the registration it already has and does nothing.
    @Test func reofferingKeepsTheRelationshipExactlyAsItWas() async {
        await isolatedReoffers {
            let server = Server()
            let registrar = representation(server)
            registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
            offer(registrar, token: [0x01, 0x02])
            await settle()

            RemoteMediaReofferSignal.request()
            offer(registrar, token: [0x01, 0x02])
            await settle()

            #expect(server.registrations.count == 2)
            #expect(server.registrations[0] == server.registrations[1])
            #expect(server.registrations[1].generation == "A")
            #expect(server.registrations[1].generationSequence == 10)
            #expect(server.registrations[1].pushToken == "0102")
        }
    }

    /// One request, one re-offer. A host app that raises it on every foreground must not turn every
    /// state update into a POST.
    @Test func oneRequestCausesOneReoffer() async {
        await isolatedReoffers {
            let server = Server()
            let registrar = representation(server)
            registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
            offer(registrar, token: [0x01, 0x02])
            await settle()

            RemoteMediaReofferSignal.request()
            for _ in 0 ..< 5 {
                offer(registrar, token: [0x01, 0x02])
            }
            await settle()

            #expect(server.registrations.count == 2)
        }
    }

    /// A representation that has never looked adopts whatever is outstanding without acting on it,
    /// because being new is already a reason to offer once.
    @Test func aFreshRepresentationDoesNotDoubleOffer() async {
        await isolatedReoffers {
            RemoteMediaReofferSignal.request()
            let server = Server()
            let registrar = representation(server)
            registrar.adopt(lifetime: .init(generation: "A", sequence: 10))
            offer(registrar, token: [0x01, 0x02])
            await settle()

            #expect(server.registrations.count == 1)
        }
    }
}
