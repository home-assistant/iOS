import Combine
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct VoiceToolsServerSettingsViewModelTests {
    private func withTestDatabase(_ work: () throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try work()
    }

    /// The screen owns the settings rather than editing a parent's copy, so it is also what has to
    /// persist them: nothing else writes this row.
    @Test func persistsEveryChangeToTheStoredSettings() throws {
        try withTestDatabase {
            let viewModel = VoiceToolsServerSettingsViewModel(
                configuration: VoiceToolsServerConfiguration.config,
                controller: nil
            )

            viewModel.configuration.isEnabled = true
            #expect(VoiceToolsServerConfiguration.config.isEnabled == true)

            viewModel.configuration.port = 10801
            #expect(VoiceToolsServerConfiguration.config.port == 10801)
        }
    }

    /// The initial value is the one just read from the database, so it must not be written straight
    /// back out as a change.
    @Test func doesNotSaveTheValueItStartedWith() throws {
        try withTestDatabase {
            VoiceToolsServerConfiguration(isEnabled: true, port: 10801).save()

            _ = VoiceToolsServerSettingsViewModel(
                configuration: VoiceToolsServerConfiguration.config,
                controller: nil
            )

            #expect(VoiceToolsServerConfiguration.config.isEnabled == true)
            #expect(VoiceToolsServerConfiguration.config.port == 10801)
        }
    }

    /// Previews and snapshot tests inject the state they need to show; the live screen mirrors the
    /// controller instead.
    @Test func showsTheInjectedStateWithoutAController() {
        let viewModel = VoiceToolsServerSettingsViewModel(
            configuration: .init(),
            controller: nil,
            state: .running(port: 10700),
            isSpeechRecognitionAuthorized: false
        )

        #expect(viewModel.state == .running(port: 10700))
        #expect(viewModel.isSpeechRecognitionAuthorized == false)
    }

    @Test func mirrorsTheControllerState() throws {
        try withTestDatabase {
            let controller = WyomingServerController()
            let viewModel = VoiceToolsServerSettingsViewModel(
                configuration: .init(),
                controller: controller,
                state: .running(port: 1)
            )

            // The controller is the source of truth once there is one, so the injected state is
            // ignored.
            #expect(viewModel.state == .stopped)

            // And the screen keeps following it, which is how the status row goes live.
            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: true, port: 10804))
            #expect(viewModel.state != .stopped)

            controller.applyConfiguration(VoiceToolsServerConfiguration(isEnabled: false))
        }
    }
}
