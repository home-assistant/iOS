import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

/// A form row for a Jinja template: shows the template's rendered result (falling back to the
/// template source, then the placeholder), and opens the full editor sheet when tapped.
struct JinjaTemplateButton: View {
    let server: Server
    /// The sheet's navigation title — the name of what this template feeds.
    let title: String
    @Binding var text: String
    var placeholder: String
    /// When set, a valid hex render shows a color swatch instead of plain text.
    var expectsColor: Bool

    /// Renders the saved template for the row label; re-evaluated whenever the sheet commits.
    @StateObject private var renderer: TemplateRenderer
    @State private var showEditor = false

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
        _renderer = StateObject(wrappedValue: TemplateRenderer(server: server, debounceInterval: 2))
    }

    var body: some View {
        Button {
            showEditor = true
        } label: {
            HStack(spacing: DesignSystem.Spaces.two) {
                Group {
                    if case let .success(value) = renderer.output, !value.isEmpty {
                        if expectsColor, let hex = WatchComplicationConfig.normalizedHexColor(from: value) {
                            HStack(spacing: DesignSystem.Spaces.one) {
                                Circle()
                                    .fill(Color(uiColor: UIColor(hex: hex)))
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1))
                                Text(verbatim: hex)
                                    .font(.body.monospaced())
                            }
                        } else {
                            // The rendered version of the template stands in for the value.
                            Text(verbatim: value)
                                .lineLimit(2)
                        }
                    } else if !text.isEmpty {
                        // No render (yet) — fall back to the template source.
                        Text(verbatim: text)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(verbatim: placeholder)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemSymbol: .chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) {
            JinjaTemplateEditorSheet(
                server: server,
                title: title,
                text: $text,
                placeholder: placeholder,
                expectsColor: expectsColor
            )
        }
        // The template only changes when the sheet commits (no typing here), so evaluate immediately.
        .onChange(of: text) { newValue in
            renderer.updateTemplate(newValue, skipDelay: true)
        }
        .onChange(of: server.identifier.rawValue) { _ in
            renderer.updateServer(server)
        }
        .onAppear {
            renderer.updateTemplate(text, skipDelay: true)
        }
    }
}

#Preview {
    // swiftlint:disable prohibit_environment_assignment
    Current.servers = FakeServerManager(initial: 1)
    // swiftlint:enable prohibit_environment_assignment
    return Form {
        Section {
            JinjaTemplateButton(
                server: Current.servers.all.first!,
                title: "Display name",
                text: .constant("{{ states('sensor.solar_power') | round(1) }} kW"),
                placeholder: "{{ states('sensor.x') }}"
            )
        } header: {
            Text(verbatim: "With template (fallback label)")
        }

        Section {
            JinjaTemplateButton(
                server: Current.servers.all.first!,
                title: "Text color",
                text: .constant(""),
                placeholder: "{{ … }} → #RRGGBB",
                expectsColor: true
            )
        } header: {
            Text(verbatim: "Empty (placeholder label)")
        }
    }
}
