import GRDB
import Shared
import SwiftUI
import UIKit

/// The Jinja template editor used by the complication builder: the evaluated result at the top
/// (live, debounced while typing — loading spinner, rendered value, error message, or a color
/// swatch), and below it a syntax-highlighted text view with autocomplete chips above the keyboard.
struct JinjaTemplateView: View {
    let server: Server
    @Binding var text: String
    var placeholder: String
    /// When set, the result is expected to be a hex color: a valid render shows a swatch, anything
    /// else shows the invalid-hex error.
    var expectsColor: Bool

    @StateObject private var renderer: TemplateRenderer
    /// Entity ids of the server, fed to the editor's autocomplete. Loaded once, off `body`.
    @State private var entityIds: [String] = []

    init(
        server: Server,
        text: Binding<String>,
        placeholder: String = "{{ … }}",
        expectsColor: Bool = false
    ) {
        self.server = server
        self._text = text
        self.placeholder = placeholder
        self.expectsColor = expectsColor
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, debounceInterval: 2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            // The evaluation result leads, so the outcome stays visible while editing below it.
            switch renderer.output {
            case .idle:
                EmptyView()
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
                    EmptyView()
                } else if expectsColor {
                    if let hex = WatchComplicationConfig.normalizedHexColor(from: value) {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Circle()
                                .fill(Color(uiColor: UIColor(hex: hex)))
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                            Text(verbatim: hex)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            case let .failure(message):
                Text(verbatim: message)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemRed))
                    .lineLimit(4)
            }

            JinjaTextEditor(text: $text, entityIds: entityIds)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(verbatim: placeholder)
                            .font(Font(JinjaTextEditor.font))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.vertical, DesignSystem.Spaces.half)
        .onChange(of: text) { newValue in
            renderer.updateTemplate(newValue)
        }
        .onChange(of: server.identifier.rawValue) { _ in
            renderer.updateServer(server)
        }
        .onAppear {
            // An already-saved template evaluates immediately; the debounce only applies to typing.
            renderer.updateTemplate(text, skipDelay: true)
            loadEntityIds()
        }
    }

    private func loadEntityIds() {
        guard entityIds.isEmpty else { return }
        let serverId = server.identifier.rawValue
        entityIds = (try? Current.database().read { db in
            try HAAppEntity
                .filter(Column(HAAppEntity.CodingKeys.serverId.rawValue) == serverId)
                .fetchAll(db)
        }).map { $0.map(\.entityId).sorted() } ?? []
    }
}

#Preview {
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    return Form {
        Section {
            JinjaTemplateView(
                server: Current.servers.all.first!,
                text: .constant("{{ states('sensor.solar_power') | round(1) }} kW"),
                placeholder: "{{ states('sensor.x') }}"
            )
        } header: {
            Text(verbatim: "Text template")
        }

        Section {
            JinjaTemplateView(
                server: Current.servers.all.first!,
                text: .constant(""),
                placeholder: "{{ … }} → #RRGGBB",
                expectsColor: true
            )
        } header: {
            Text(verbatim: "Color template")
        }
    }
}
