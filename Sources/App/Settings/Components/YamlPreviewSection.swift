import Shared
import SwiftUI
import UIKit

/// A reusable SwiftUI section that renders a YAML preview with a share button.
///
/// Replaces the Eureka `YamlSection` used across settings forms. The YAML value
/// is produced by the `yaml` closure so callers can rebuild the string in
/// response to form changes.
struct YamlPreviewSection: View {
    let header: String
    let shareTitle: String
    let yaml: String

    @State private var showShareSheet = false
    @State private var showYamlSheet = false

    init(
        header: String,
        shareTitle: String = L10n.ActionsConfigurator.TriggerExample.share,
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

            Button {
                showShareSheet = true
            } label: {
                Label {
                    Text(shareTitle)
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemSymbol: .squareAndArrowUp)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            YamlShareSheet(activityItems: [yaml])
        }
        .sheet(isPresented: $showYamlSheet) {
            YamlCodePreviewView(yaml: yaml)
        }
    }
}

/// A SwiftUI wrapper around `UIActivityViewController` used to share YAML or
/// other plain text content from settings screens.
struct YamlShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
