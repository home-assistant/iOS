import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit
import UniformTypeIdentifiers

@MainActor
@Suite(.serialized)
struct ServerConfigurationImportPresentationTests {
    // MARK: - Opening a file

    @Test func openingAServerFilePresentsTheConfirmationScreen() throws {
        let url = try Self.writeFile(Self.serverFileJSON, in: FileManager.default.temporaryDirectory)
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = MockAppCoordinator()

        ServerConfigurationImportPresenter.present(fileURL: url, coordinator: coordinator)

        #expect(coordinator.dismissPresentedContentCallCount == 1)
        #expect(coordinator.presentedViewControllers.count == 1)
        #expect(coordinator.presentedViewControllers.first is DismissalReportingHostingController)
        // A file outside the app's inbox belongs to the user and is left alone.
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func aFileThatIsNotAServerFileIsReportedWithAnAlert() throws {
        let url = try Self.writeFile(#"{ "name": "package" }"#, in: FileManager.default.temporaryDirectory)
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = MockAppCoordinator()

        ServerConfigurationImportPresenter.present(fileURL: url, coordinator: coordinator)

        let alert = try #require(coordinator.presentedViewControllers.first as? UIAlertController)
        #expect(
            alert.message == ServerConfigurationImport.ImportError.notAServerConfigurationFile(foundKind: nil)
                .errorDescription
        )
    }

    @Test func theInboxCopyOfAnOpenedFileIsRemovedOnceRead() throws {
        let documents = try #require(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = try Self.writeFile(Self.serverFileJSON, in: inbox)
        defer { try? FileManager.default.removeItem(at: url) }

        ServerConfigurationImportPresenter.present(fileURL: url, coordinator: MockAppCoordinator())

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - After the import

    @Test func aFirstRunImportFinishesOnboarding() {
        let observer = RecordingOnboardingObserver()
        Current.onboardingObservation.register(observer: observer)
        defer { Current.onboardingObservation.unregister(observer: observer) }

        ServerConfigurationImportPresenter.importDidComplete(
            .init(guidedServers: [], completesFirstRun: true),
            coordinator: MockAppCoordinator()
        )

        #expect(observer.states == [.complete])
    }

    @Test func anImportNextToExistingServersLeavesOnboardingAlone() {
        let observer = RecordingOnboardingObserver()
        Current.onboardingObservation.register(observer: observer)
        defer { Current.onboardingObservation.unregister(observer: observer) }
        let coordinator = MockAppCoordinator()

        ServerConfigurationImportPresenter.importDidComplete(
            .init(guidedServers: [], completesFirstRun: false),
            coordinator: coordinator
        )

        #expect(observer.states.isEmpty)
        #expect(coordinator.presentedViewControllers.isEmpty)
    }

    @Test func continuingToSignInPresentsOnboardingForTheFirstServer() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.serverFileJSON.utf8))
        let coordinator = MockAppCoordinator()
        coordinator.presentedViewController = UIViewController()

        ServerConfigurationImportPresenter.importDidComplete(
            .init(guidedServers: document.servers, completesFirstRun: false),
            coordinator: coordinator
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(coordinator.presentedViewControllers.count == 1)
        let onboarding = try #require(
            coordinator.presentedViewControllers.first as? DismissalReportingHostingController
        )

        // Closing it without signing in ends the chain: nothing else is presented.
        onboarding.onDismiss?()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(coordinator.presentedViewControllers.count == 1)
    }

    @Test func signInIsAbandonedWhenThereIsNothingToPresentOver() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.serverFileJSON.utf8))
        let coordinator = MockAppCoordinator()

        ServerConfigurationImportPresenter.importDidComplete(
            .init(guidedServers: document.servers, completesFirstRun: false),
            coordinator: coordinator
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(coordinator.presentedViewControllers.isEmpty)
    }

    // MARK: - Screen

    @Test func confirmationAndResultsScreensRender() async throws {
        let document = try ServerConfigurationImport.decode(data: Data(Self.serverFileJSON.utf8))
        let viewModel = ServerConfigurationImportViewModel(
            document: document,
            runner: ServerConfigurationImportRunner(
                tokenValidator: AcceptingTokenValidator(),
                persistence: InMemoryPersistence()
            )
        )
        let window = UIWindow(frame: .init(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIHostingController(rootView: ServerConfigurationImportView(viewModel: viewModel))
        window.isHidden = false
        defer { window.isHidden = true }

        window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(viewModel.phase == .confirming)
        #expect(viewModel.hasActionableServers)

        viewModel.confirm()
        for _ in 0 ..< 100 {
            if case .finished = viewModel.phase { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.phase == .finished(.init(added: 1, skipped: 1, failed: 0, guidedRemaining: 1)))
        #expect(viewModel.guidedServersRemaining == 1)
    }

    // MARK: - Document type

    @Test func thePickerOffersTheServerFileTypeAndPlainJSON() {
        let types = ServerConfigurationUTType.importableContentTypes
        #expect(types.contains(.json))
        #expect(types.first == ServerConfigurationUTType.type)
        #expect(ServerConfigurationUTType.type.conforms(to: .json))
    }

    // MARK: - Helpers

    private static func writeFile(_ contents: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).hassconfig")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private static let serverFileJSON = """
    {
      "kind": "home-assistant-servers",
      "schemaVersion": 1,
      "servers": [
        { "name": "Home", "externalURL": "https://home.example.com", "longLivedAccessToken": "home-token" },
        { "name": "Cabin", "externalURL": "https://cabin.example.com" },
        { "name": "Cabin again", "externalURL": "https://cabin.example.com" }
      ]
    }
    """
}

private struct AcceptingTokenValidator: ServerTokenValidating {
    func validate(token: String, externalURL: URL) async throws {}
}

private final class InMemoryPersistence: ServerConfigurationPersisting, @unchecked Sendable {
    let existingServers: [(name: String, externalURL: URL?)] = []

    @discardableResult
    func add(entry: ServerConfigurationImport.ServerEntry, token: String) async throws -> Identifier<Server> {
        Identifier<Server>(rawValue: entry.name)
    }
}

private final class RecordingOnboardingObserver: OnboardingStateObserver {
    private(set) var states: [OnboardingState] = []

    func onboardingStateDidChange(to state: OnboardingState) {
        states.append(state)
    }
}
