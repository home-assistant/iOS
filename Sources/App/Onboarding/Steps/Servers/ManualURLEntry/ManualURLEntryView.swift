import Shared
import SwiftUI

struct ManualURLEntryView: View {
    enum Constants {
        static let http = "http://"
        static let https = "https://"
    }

    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @FocusState private var focused: Bool?
    @State private var showInvalidURLError = false

    let connectAction: (URL) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(L10n.Onboarding.ManualSetup.TextField.title) {
                    HATextField(
                        placeholder: L10n.Onboarding.ManualSetup.TextField.placeholder,
                        text: $urlString,
                        keyboardType: .URL
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .focused($focused, equals: true)
                    .onAppear {
                        focused = true
                    }
                }

                httpOrHttpsSection
            }
            .listStyle(.plain)
            .navigationTitle(L10n.Onboarding.ManualSetup.title)
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                connectButton
            }
            .alert(isPresented: $showInvalidURLError) {
                Alert(
                    title: Text(verbatim: L10n.Onboarding.ManualSetup.InputError.title),
                    message: Text(verbatim: L10n.Onboarding.ManualSetup.InputError.message),
                    dismissButton: .default(Text(verbatim: L10n.okLabel))
                )
            }
        }
    }

    // View which displays helpers to add http or https to the URL
    @ViewBuilder
    private var httpOrHttpsSection: some View {
        let cleanedURL = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // 7 is the count of http:// chars
        let minCharsToActivateSection = 7
        if !cleanedURL.isEmpty,
           !cleanedURL.starts(with: Constants.http),
           !cleanedURL.starts(with: Constants.https),
           cleanedURL.count >= minCharsToActivateSection {
            Section(L10n.Onboarding.ManualSetup.HelperSection.title) {
                HStack {
                    Button(action: {
                        urlString = "\(Constants.http)\(urlString)"
                    }, label: {
                        Text(verbatim: "\(Constants.http)\(urlString)")
                    })
                }
                Button(action: {
                    urlString = "\(Constants.https)\(urlString)"
                }, label: {
                    Text(verbatim: "\(Constants.https)\(urlString)")
                })
            }
            .buttonStyle(.pillButton)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var connectButton: some View {
        Button {
            if let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                dismiss()
                connectAction(url)
            } else {
                showInvalidURLError = true
            }
        } label: {
            Text(L10n.Onboarding.ManualSetup.connect)
        }
        .buttonStyle(.primaryButton)
        .padding()
        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            ManualURLEntryView { _ in
            }
        }
}
