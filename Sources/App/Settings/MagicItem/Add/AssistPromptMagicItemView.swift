import Foundation
import Shared
import SwiftUI

struct AssistPromptMagicItemView: View {
    enum Mode {
        case add
        case edit

        var buttonTitle: String {
            switch self {
            case .add:
                return L10n.MagicItem.add
            case .edit:
                return L10n.MagicItem.edit
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var selectedServerId: String?
    @State private var selectedPipelineId: String?
    @State private var title: String
    @State private var prompt: String

    private let mode: Mode
    private let itemId: String?
    private let customization: MagicItem.Customization?
    private let save: (MagicItem) -> Void

    init(
        mode: Mode,
        item: MagicItem? = nil,
        save: @escaping (MagicItem) -> Void
    ) {
        self.mode = mode
        self.itemId = item?.id
        self.customization = item?.customization ?? .init(iconColor: MagicItem.defaultAssistIconColorHex)
        self.save = save
        self._selectedServerId = State(initialValue: item?.serverId)
        self._selectedPipelineId = State(initialValue: item?.assistPipelineId ?? item?.id)
        self._title = State(initialValue: item?.displayText ?? "")
        self._prompt = State(initialValue: item?.assistPrompt ?? "")
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(verbatim: L10n.MagicItem.Action.Assist.Pipeline.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AssistPipelinePicker(
                        selectedServerId: $selectedServerId,
                        selectedPipelineId: $selectedPipelineId
                    )
                }
            } header: {
                Text(verbatim: L10n.Widgets.Action.Name.assist)
            }

            Section {
                TextField(L10n.MagicItem.AssistPrompt.Title.title, text: $title)
            } header: {
                Text(verbatim: L10n.MagicItem.AssistPrompt.Title.title)
            }

            Section {
                TextField(L10n.MagicItem.AssistPrompt.Prompt.title, text: $prompt)
            } header: {
                Text(verbatim: L10n.MagicItem.AssistPrompt.Prompt.title)
            } footer: {
                Text(verbatim: L10n.MagicItem.AssistPrompt.Prompt.footer)
            }
        }
        .navigationTitle(L10n.MagicItem.AssistPrompt.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(mode.buttonTitle) {
                    saveItem()
                }
                .disabled(!canSave)
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        selectedServerId != nil && selectedPipelineId != nil && !trimmedTitle.isEmpty && !trimmedPrompt.isEmpty
    }

    private func saveItem() {
        guard let selectedServerId, let selectedPipelineId else { return }

        save(.init(
            id: itemId ?? UUID().uuidString,
            serverId: selectedServerId,
            type: .assistPrompt,
            customization: customization,
            displayText: trimmedTitle,
            assistPrompt: trimmedPrompt,
            assistPipelineId: selectedPipelineId
        ))
        dismiss()
    }
}

#Preview {
    NavigationView {
        AssistPromptMagicItemView(mode: .add) { _ in }
    }
}
