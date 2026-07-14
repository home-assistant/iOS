import GRDB
import Shared
import SwiftUI
import UIKit

/// The full Jinja editor presented from `JinjaTemplateButton`: the evaluated result in its own
/// section at the top (with a placeholder until there is one), the syntax-highlighted editor below
/// with context-aware entity suggestion pills as the section footer, and Cancel/Done that discard
/// or commit the draft.
struct JinjaTemplateEditorSheet: View {
    let server: Server
    let title: String
    @Binding var text: String
    var placeholder: String
    /// When set, the result is expected to be a hex color: a valid render shows a swatch, anything
    /// else shows the invalid-hex error.
    var expectsColor: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @StateObject private var renderer: TemplateRenderer
    /// The server's entities keyed by entity id, feeding the suggestion pills. Loaded once, off
    /// `body`.
    @State private var entitiesById: [String: HAAppEntity] = [:]
    /// Entity ids of the server (sorted), feeding the suggestion filtering.
    @State private var entityIds: [String] = []
    /// Context lines (Floor • Area • Device) for suggested entities, computed lazily per entity —
    /// they require database lookups, so only the currently suggested ones are resolved.
    @State private var entitySubtitles: [String: String] = [:]
    /// The editor's cursor location, so suggestions adapt to what is being typed.
    @State private var cursorLocation = 0
    /// Insertion channel into the editor: set by a pill tap or the entity picker, consumed by the
    /// editor.
    @State private var pendingInsertion: JinjaTemplateSuggestion?
    @State private var showEntityPicker = false
    @State private var pickedEntity: HAAppEntity?
    @State private var replacingEntityReference: JinjaEntityReference?

    init(
        server: Server,
        title: String,
        text: Binding<String>,
        placeholder: String = "{{ … }}",
        expectsColor: Bool = false
    ) {
        self.server = server
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.expectsColor = expectsColor
        self._draft = State(initialValue: text.wrappedValue)
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, debounceInterval: 2))
    }

    private var provider: JinjaAutocompleteProvider {
        JinjaAutocompleteProvider(entityIds: entityIds)
    }

    private var suggestions: [JinjaTemplateSuggestion] {
        provider.entitySuggestions(text: draft, cursorLocation: cursorLocation)
    }

    /// The suggestion pills' display items: entity name + context line for each suggested id.
    private var suggestionItems: [JinjaEntitySuggestionsView.Item] {
        suggestions.map { suggestion in
            JinjaEntitySuggestionsView.Item(
                suggestion: suggestion,
                name: entitiesById[suggestion.label]?.name ?? suggestion.label,
                subtitle: entitySubtitles[suggestion.label]
            )
        }
    }

    private var entityReferences: [JinjaEntityReference] {
        provider.entityReferences(in: draft).map { reference in
            JinjaEntityReference(
                entityId: reference.entityId,
                range: reference.range,
                name: entitiesById[reference.entityId]?.name,
                subtitle: entitiesById[reference.entityId]?.contextualSubtitle
            )
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // The evaluated result leads, in its own section, so the outcome stays visible
                // while editing below it.
                Section {
                    switch renderer.output {
                    case .idle:
                        resultPlaceholder
                    case .loading:
                        HStack(spacing: DesignSystem.Spaces.one) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.Watch.Complications.Builder.templateEvaluating)
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    case let .success(value):
                        if value.isEmpty {
                            resultPlaceholder
                        } else if expectsColor {
                            if let hex = WatchComplicationConfig.normalizedHexColor(from: value) {
                                HStack(spacing: DesignSystem.Spaces.one) {
                                    Circle()
                                        .fill(Color(uiColor: UIColor(hex: hex)))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    Text(verbatim: hex)
                                        .font(.footnote.monospaced())
                                }
                            } else {
                                Text(L10n.Watch.Complications.Builder.templateInvalidHex)
                                    .font(.footnote)
                                    .foregroundStyle(Color(.systemRed))
                                    .lineLimit(3)
                            }
                        } else {
                            Text(verbatim: value)
                                .font(.footnote.monospaced())
                                .lineLimit(6)
                        }
                    case let .failure(message):
                        Text(verbatim: message)
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                            .lineLimit(6)
                    }
                } header: {
                    Text(L10n.Watch.Complications.Builder.templateResult)
                }

                Section {
                    JinjaTextEditor(
                        text: $draft,
                        cursorLocation: $cursorLocation,
                        pendingInsertion: $pendingInsertion,
                        entityReferences: entityReferences,
                        onEntityTap: { reference in
                            replacingEntityReference = reference
                            pickedEntity = nil
                            showEntityPicker = true
                        },
                        autoFocus: true
                    )
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text(verbatim: placeholder)
                                .font(Font(JinjaTextEditor.font))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                } footer: {
                    // Suggestions only appear once the user is typing an entity id (inside an open
                    // quote); the sheet opens without them.
                    if !suggestionItems.isEmpty {
                        JinjaEntitySuggestionsView(
                            items: suggestionItems,
                            onSelect: { pendingInsertion = $0 },
                            onMore: {
                                replacingEntityReference = nil
                                showEntityPicker = true
                            }
                        )
                    }
                }
            }
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancelLabel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.doneLabel) {
                        text = draft
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: draft) { newValue in
            renderer.updateTemplate(newValue)
        }
        .onChange(of: suggestions.map(\.label)) { entityIds in
            resolveSubtitles(for: entityIds)
        }
        .onAppear {
            // An already-saved template evaluates immediately; the debounce only applies to typing.
            renderer.updateTemplate(draft, skipDelay: true)
            loadEntities()
        }
        .sheet(isPresented: $showEntityPicker) {
            NavigationView {
                // Pre-filtered by the same text the suggestion pills are filtered by (the prefix
                // typed inside an open quote).
                EntityPicker(
                    selectedServerId: server.identifier.rawValue,
                    selectedEntity: $pickedEntity,
                    domainFilter: nil,
                    mode: .list,
                    initialSearchTerm: replacingEntityReference?.entityId ?? provider.quotedPrefix(
                        text: draft,
                        cursorLocation: cursorLocation
                    )
                )
            }
            .navigationViewStyle(.stack)
            .presentationDragIndicator(.visible)
        }
        .onChange(of: pickedEntity?.id) { _ in
            guard let entity = pickedEntity else { return }
            showEntityPicker = false
            if let replacingEntityReference {
                pendingInsertion = JinjaTemplateSuggestion(
                    label: entity.entityId,
                    insertion: entity.entityId,
                    replacementRange: replacingEntityReference.range
                )
            } else {
                pendingInsertion = provider.entityInsertion(
                    for: entity.entityId,
                    text: draft,
                    cursorLocation: cursorLocation
                )
            }
            replacingEntityReference = nil
            pickedEntity = nil
        }
    }

    private var resultPlaceholder: some View {
        Text(L10n.Watch.Complications.Builder.templateResultPlaceholder)
            .font(.footnote)
            .foregroundStyle(.secondary.opacity(0.6))
    }

    private func loadEntities() {
        guard entitiesById.isEmpty else { return }
        let serverId = server.identifier.rawValue
        let entities = (try? Current.database().read { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .fetchAll(db)
        }) ?? []
        entitiesById = Dictionary(entities.map { ($0.entityId, $0) }, uniquingKeysWith: { first, _ in first })
        entityIds = entities.map(\.entityId).sorted()
    }

    /// Resolves and caches the context line for the suggested entities. Done outside `body` (and
    /// only for the visible suggestions) because each line needs database lookups.
    private func resolveSubtitles(for suggestedIds: [String]) {
        for entityId in suggestedIds where entitySubtitles[entityId] == nil {
            // Cache misses as "" so a context-less entity isn't re-resolved on every keystroke.
            entitySubtitles[entityId] = entitiesById[entityId]?.contextualSubtitle ?? ""
        }
    }
}

#Preview {
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    return Text(verbatim: "Host")
        .sheet(isPresented: .constant(true)) {
            JinjaTemplateEditorSheet(
                server: Current.servers.all.first!,
                title: "Display name",
                text: .constant("{{ states('sensor.solar_power') | round(1) }} kW")
            )
        }
}
