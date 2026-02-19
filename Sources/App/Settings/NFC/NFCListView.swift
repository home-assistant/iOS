import PromiseKit
import Shared
import SwiftUI

struct NFCListView: View {
    @State private var showWriteOptions = false
    @State private var showManualInput = false
    @State private var manualIdentifier = ""
    @State private var lastManualIdentifier: String?
    @State private var tagIdentifier: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isNavigatingToTag = false

    var body: some View {
        ZStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.Nfc.List.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Link(destination: AppConstants.WebURLs.nfcDocs) {
                            HStack {
                                Text(L10n.Nfc.List.learnMore)
                                Spacer()
                                Image(systemSymbol: .arrowUpForwardSquare)
                                    .font(.caption)
                            }
                        }
                    }
                }

                if Current.tags.isNFCAvailable {
                    Section {
                        Button {
                            readTag()
                        } label: {
                            Label {
                                Text(L10n.Nfc.List.readTag)
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(uiImage: MaterialDesignIcons.nfcVariantIcon.image(
                                    ofSize: CGSize(width: 24, height: 24),
                                    color: .label
                                ))
                                .renderingMode(.template)
                            }
                        }

                        Button {
                            showWriteOptions = true
                        } label: {
                            Label {
                                Text(L10n.Nfc.List.writeTag)
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(uiImage: MaterialDesignIcons.nfcTapIcon.image(
                                    ofSize: CGSize(width: 24, height: 24),
                                    color: .label
                                ))
                                .renderingMode(.template)
                            }
                        }
                    }
                } else {
                    Section {
                        Text(L10n.Nfc.notAvailable)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.Nfc.List.title)

            // Hidden NavigationLink for programmatic navigation
            NavigationLink(
                destination: Group {
                    if let identifier = tagIdentifier {
                        NFCTagView(identifier: identifier)
                    }
                },
                isActive: $isNavigatingToTag
            ) {
                EmptyView()
            }
            .hidden()
        }
        .confirmationDialog(
            L10n.Nfc.Write.IdentifierChoice.title,
            isPresented: $showWriteOptions,
            titleVisibility: .visible
        ) {
            Button(L10n.Nfc.Write.IdentifierChoice.random) {
                writeRandomTag()
            }

            Button(L10n.Nfc.Write.IdentifierChoice.manual) {
                // Pre-populate with last manual identifier before showing alert
                if let lastValue = lastManualIdentifier {
                    manualIdentifier = lastValue
                }
                showManualInput = true
            }

            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(L10n.Nfc.Write.IdentifierChoice.message)
        }
        .alert(L10n.Nfc.Write.ManualInput.title, isPresented: $showManualInput) {
            TextField("", text: $manualIdentifier)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            Button(L10n.doneLabel) {
                if !manualIdentifier.isEmpty {
                    lastManualIdentifier = manualIdentifier
                    writeTag(with: manualIdentifier)
                }
            }
            .disabled(manualIdentifier.isEmpty)

            Button(L10n.cancelLabel, role: .cancel) {
                manualIdentifier = ""
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text(errorMessage ?? L10n.errorLabel),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
    }

    private func readTag() {
        perform(with: Current.tags.readNFC())
    }

    private func writeRandomTag() {
        perform(with: Current.tags.writeRandomNFC())
    }

    private func writeTag(with identifier: String) {
        perform(with: Current.tags.writeNFC(value: identifier))
    }

    private func perform(with promise: Promise<String>) {
        firstly {
            promise
        }.done { value in
            Current.Log.info("NFC tag with value \(value)")
            tagIdentifier = value
            isNavigatingToTag = true
        }.catch { error in
            Current.Log.error(error)

            if error is TagManagerError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
