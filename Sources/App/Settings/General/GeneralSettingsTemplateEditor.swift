import HAKit
import Shared
import SwiftUI

struct GeneralSettingsTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var template: String = Current.settingsStore.menuItemTemplate?.template ?? ""
    @State private var renderedTemplate: String = ""
    @State private var selectedServerId: String?
    @State private var isLoading = false
    @State private var currentTask: Task<Void, Never>?

    private var selectedServer: Server? {
        guard let selectedServerId else { return nil }
        return Current.servers.all.first(where: { $0.identifier.rawValue == selectedServerId })
    }

    var body: some View {
        List {
            Section(L10n.WebView.UniqueServerSelection.title) {
                ServersPickerPillList(selectedServerId: $selectedServerId)
                    .padding(.vertical, Spaces.half)
                    .listRowBackground(Color(uiColor: .systemBackground))
            }
            if selectedServerId != nil {
                Section(header: Text(L10n.SettingsDetails.General.MenuBarText.title)) {
                    TextField("{{ now() }}", text: $template)
                }
                Section(L10n.previewOutput) {
                    Text(renderedTemplate)
                }
            }
        }
        .navigationTitle(L10n.Settings.TemplateEdit.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.saveLabel) {
                    saveTemplate()
                }
            }
        }
        .onAppear {
            selectedServerId = Current.settingsStore.menuItemTemplate?.server.identifier.rawValue ?? nil
            renderTemplate()
        }
        .onChange(of: template) { newValue in
            renderTemplate(newValue)
        }
    }

    private func saveTemplate() {
        guard let server = selectedServer else { return }
        Current.settingsStore.menuItemTemplate = (server, template)
        dismiss()
    }

    private func renderTemplate(_ template: String? = nil) {
        let template = template ?? self.template
        guard let server = selectedServer, let api = Current.api(for: server) else { return }
        isLoading = true
        currentTask?.cancel()
        currentTask = Task {
            let result = await withCheckedContinuation { continuation in
                api.connection.send(.init(
                    type: .rest(.post, "template"),
                    data: ["template": template],
                    shouldRetry: true
                )) { result in
                    continuation.resume(returning: result)
                }
            }

            var data: HAData?
            switch result {
            case let .success(resultData):
                data = resultData
            case let .failure(error):
                Current.Log.error("Error rendering template: \(error)")
                renderedTemplate = error.localizedDescription
            }
            guard let data else {
                Current.Log.error("No data returned from template rendering")
                renderedTemplate = "-"
                return
            }
            switch data {
            case let .primitive(response):
                renderedTemplate = response as? String ?? "-"
            default:
                Current.Log.error("Unexpected data type returned from template rendering")
                renderedTemplate = "-"
            }
        }
    }
}
