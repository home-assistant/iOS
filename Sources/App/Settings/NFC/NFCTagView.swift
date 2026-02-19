import Shared
import SwiftUI
import UIKit

struct NFCTagView: View {
    let identifier: String

    @State private var showShareSheet = false
    @State private var showYamlSheet = false

    var body: some View {
        List {
            identifierSection
            actionsSection
            exampleTriggerSection
        }
        .navigationTitle(L10n.Nfc.Detail.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            NFCShareSheet(activityItems: [identifier])
        }
        .sheet(isPresented: $showYamlSheet) {
            YamlCodeView(yaml: yamlExample)
        }
    }

    private var identifierSection: some View {
        Section(L10n.Nfc.Detail.tagValue) {
            Text(identifier)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIPasteboard.general.string = identifier
            } label: {
                Label {
                    Text(L10n.Nfc.Detail.copy)
                        .foregroundColor(.primary)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.contentCopyIcon.image(
                        ofSize: CGSize(width: 24, height: 24),
                        color: .label
                    ))
                    .renderingMode(.template)
                }
            }

            Button {
                showShareSheet = true
            } label: {
                Label {
                    Text(L10n.Nfc.Detail.share)
                        .foregroundColor(.primary)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.exportIcon.image(
                        ofSize: CGSize(width: 24, height: 24),
                        color: .label
                    ))
                    .renderingMode(.template)
                    .rotationEffect(.degrees(-90))
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Current.Log.info("duplicating \(identifier)")
                Current.tags.writeNFC(value: identifier).cauterize()
            } label: {
                Label {
                    Text(L10n.Nfc.Detail.duplicate)
                        .foregroundColor(.primary)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.nfcTapIcon.image(
                        ofSize: CGSize(width: 24, height: 24),
                        color: .label
                    ))
                    .renderingMode(.template)
                }
            }

            Button {
                Current.tags.fireEvent(tag: identifier).cauterize()
            } label: {
                Label {
                    Text(L10n.Nfc.Detail.fire)
                        .foregroundColor(.primary)
                } icon: {
                    Image(uiImage: MaterialDesignIcons.bellRingOutlineIcon.image(
                        ofSize: CGSize(width: 24, height: 24),
                        color: .label
                    ))
                    .renderingMode(.template)
                }
            }
        }
    }

    private var exampleTriggerSection: some View {
        Section(L10n.Nfc.Detail.exampleTrigger) {
            Button {
                showYamlSheet = true
            } label: {
                HStack {
                    Text(yamlExample)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemSymbol: .chevronRight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var yamlExample: String {
        """
        - platform: tag
          tag_id: \(identifier)
        """
    }
}

// MARK: - Activity View Controller (Share Sheet)

struct NFCShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - YAML Code View

struct YamlCodeView: View {
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

#Preview {
    NavigationView {
        NFCTagView(identifier: "abc123-def456-ghi789")
    }
}
