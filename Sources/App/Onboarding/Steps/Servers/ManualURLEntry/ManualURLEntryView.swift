import Shared
import SwiftUI

struct ManualURLEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @FocusState private var focused: Bool?
    @State private var showInvalidURLError = false

    let connectAction: (URL) -> Void

    // Centralized schemes to avoid hardcoded duplication
    private enum URLScheme: String, CaseIterable {
        case http = "http://"
        case https = "https://"
    }

    // Use the length of the shortest scheme to determine activation threshold
    private let minCharsToActivateSection = URLScheme.allCases.map(\.rawValue.count).min() ?? 0

    var body: some View {
        NavigationView {
            List {
                Section(L10n.Onboarding.ManualSetup.TextField.title) {
                    TextField(L10n.Onboarding.ManualSetup.TextField.placeholder, text: $urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .focused($focused, equals: true)
                        .onAppear {
                            focused = true
                        }
                }

                httpOrHttpsSection
            }
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

        // Check if the input already starts with any of our supported schemes
        let hasSupportedScheme = URLScheme.allCases.contains { cleanedURL.hasPrefix($0.rawValue) }

        if !cleanedURL.isEmpty,
           !hasSupportedScheme,
           cleanedURL.count >= minCharsToActivateSection {
            Section(L10n.Onboarding.ManualSetup.HelperSection.title) {
                ForEach(URLScheme.allCases, id: \.rawValue) { scheme in
                    Button(action: {
                        urlString = scheme.rawValue + urlString
                    }, label: {
                        Text(verbatim: scheme.rawValue + urlString)
                    })
                }
            }
            .buttonStyle(.primaryButton)
            .listRowBackground(Color.clear)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
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
