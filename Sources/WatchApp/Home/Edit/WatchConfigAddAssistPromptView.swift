import Shared
import SwiftUI

/// Creates an Assist prompt item on the watch: pick the pipeline that will run it, name it, and
/// write the prompt (dictation or scribble). Running the item sends the prompt straight to Assist,
/// so there is nothing to listen to.
struct WatchConfigAddAssistPromptView: View {
    let viewModel: WatchHomeViewModel
    /// When set, the prompt goes into this folder instead of the root.
    let folderId: String?
    let finish: () -> Void

    @State private var options: [WatchAssistPipelineOption] = []
    @State private var selectedOptionId: String?
    @State private var title = ""
    @State private var prompt = ""

    private var selectedOption: WatchAssistPipelineOption? {
        options.first(where: { $0.id == selectedOptionId })
    }

    private var canSave: Bool {
        selectedOption != nil && !trimmedTitle.isEmpty && !trimmedPrompt.isEmpty
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if options.isEmpty {
                Text(verbatim: L10n.Watch.Config.Assist.noPipelines)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    Picker(L10n.Watch.Config.Assist.pipeline, selection: $selectedOptionId) {
                        ForEach(options) { option in
                            Text(verbatim: pickerLabel(for: option))
                                .tag(Optional(option.id))
                        }
                    }
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
                }

                Section {
                    Button(action: save) {
                        Text(verbatim: L10n.Watch.Config.Edit.addButton)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.MagicItem.AssistPrompt.navigationTitle))
        .onAppear(perform: load)
    }

    /// Several servers can each offer a "Preferred" entry, so the server name is part of the label
    /// when there is more than one.
    private func pickerLabel(for option: WatchAssistPipelineOption) -> String {
        let serverIds = Set(options.map(\.serverId))
        guard serverIds.count > 1 else { return option.name }
        return "\(option.serverName) • \(option.name)"
    }

    private func load() {
        guard options.isEmpty else { return }
        options = WatchAssistPipelineOption.all()
        selectedOptionId = selectedOptionId ?? options.first?.id
    }

    private func save() {
        guard let selectedOption else { return }
        let item = MagicItem(
            id: UUID().uuidString,
            serverId: selectedOption.serverId,
            type: .assistPrompt,
            customization: .init(iconColor: MagicItem.defaultAssistIconColorHex),
            displayText: trimmedTitle,
            assistPrompt: trimmedPrompt,
            assistPipelineId: selectedOption.pipelineId
        )
        let info = Current.magicItemProvider().getInfo(for: item)
        if let folderId {
            viewModel.addItemToFolder(folderId: folderId, item: item, info: info)
        } else {
            viewModel.addItem(item, info: info)
        }
        viewModel.saveConfig()
        finish()
    }
}

#Preview {
    MaterialDesignIcons.register()
    return NavigationView {
        WatchConfigAddAssistPromptView(viewModel: WatchHomeViewModel(), folderId: nil, finish: {})
    }
}
