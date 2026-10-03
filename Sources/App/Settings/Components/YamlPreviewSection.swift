import Shared
import SwiftUI

/// A reusable SwiftUI section that renders a YAML preview with a share button.
///
/// Replaces the Eureka `YamlSection` used across settings forms. The YAML value
/// is passed in via `yaml`; callers are responsible for rebuilding the string
/// in response to form changes (typically via a derived computed property).
struct YamlPreviewSection: View {
    let header: String
    let shareTitle: String
    let yaml: String

    @State private var showYamlSheet = false

    init(
        header: String,
        shareTitle: String = L10n.YamlPreview.share,
        yaml: String
    ) {
        self.header = header
        self.shareTitle = shareTitle
        self.yaml = yaml
    }

    var body: some View {
        Section(header: Text(header)) {
            Button {
                showYamlSheet = true
            } label: {
                HStack(alignment: .top) {
                    Text(yaml)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemSymbol: .chevronRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ShareLink(item: yaml) {
                Label {
                    Text(shareTitle)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemSymbol: .squareAndArrowUp)
                }
            }
        }
        .sheet(isPresented: $showYamlSheet) {
            YamlCodePreviewView(yaml: yaml)
        }
    }
}

/// Full-screen readable YAML preview, presented as a sheet from
/// `YamlPreviewSection`. Provides a copy-to-pasteboard button and close action.
struct YamlCodePreviewView: View {
    let yaml: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(yaml)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .navigationTitle("YAML")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.closeLabel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = yaml
                    } label: {
                        Label(L10n.Nfc.Detail.copy, systemSymbol: .docOnDoc)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
