import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the Assist prompt editor and its pipeline picker out against stored pipelines (so the picker
/// never asks a server for them), for a new item and for an existing one.
@MainActor
@Suite(.serialized)
struct AssistPromptMagicItemViewRenderTests {
    private static let serverId = "assist-prompt-server"

    @Test func modesNameTheirButton() {
        #expect(AssistPromptMagicItemView.Mode.add.buttonTitle == L10n.MagicItem.add)
        #expect(AssistPromptMagicItemView.Mode.edit.buttonTitle == L10n.MagicItem.edit)
    }

    @Test func rendersANewPrompt() throws {
        try withPipelines {
            var saved: [MagicItem] = []
            render(AssistPromptMagicItemView(mode: .add) { saved.append($0) })
            #expect(saved.isEmpty)
        }
    }

    @Test func rendersAnExistingPrompt() throws {
        try withPipelines {
            let item = MagicItem(
                id: "prompt-1",
                serverId: Self.serverId,
                type: .assistPrompt,
                displayText: "Good night",
                assistPrompt: "Turn everything off",
                assistPipelineId: "office"
            )
            render(AssistPromptMagicItemView(mode: .edit, item: item) { _ in })
        }
    }

    @Test func pickerShowsThePlaceholderOrTheSelectedPipeline() throws {
        try withPipelines {
            render(AssistPipelinePicker(selectedServerId: .constant(nil), selectedPipelineId: .constant(nil)))
            render(AssistPipelinePicker(
                selectedServerId: .constant(Self.serverId),
                selectedPipelineId: .constant("office")
            ))
            render(AssistPipelinePicker(
                selectedServerId: .constant(Self.serverId),
                selectedPipelineId: .constant("")
            ))
            render(AssistPipelinePicker(
                selectedServerId: .constant(Self.serverId),
                selectedPipelineId: .constant("missing")
            ))
        }
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1000))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withPipelines(_ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let servers = FakeServerManager(initial: 0)
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        try database.write { db in
            try AssistPipelines(
                serverId: Self.serverId,
                preferredPipeline: "home",
                pipelines: [Pipeline(id: "home", name: "Home"), Pipeline(id: "office", name: "Office")]
            ).insert(db)
        }
        Current.database = { database }

        try body()
    }
}
