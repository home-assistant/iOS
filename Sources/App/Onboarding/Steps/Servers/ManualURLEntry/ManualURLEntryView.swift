import Shared
import SwiftUI

struct ManualURLEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString: String
    @FocusState private var focused: Bool?
    @State private var showInvalidURLError = false

    let connectAction: (URL) -> Void

    init(initialURL: String = "", connectAction: @escaping (URL) -> Void) {
        self._urlString = State(initialValue: initialURL)
        self.connectAction = connectAction
    }

    // Centralized schemes to avoid hardcoded duplication
    private enum URLScheme: String, CaseIterable {
        case http = "http://"
        case https = "https://"
    }

    // Use the length of the shortest scheme to determine activation threshold
    private let minCharsToActivateSection = URLScheme.allCases.map(\.rawValue.count).min() ?? 0

    var body: some View {
        NavigationView {
            BaseOnboardingView(illustration: {
                Image(.Onboarding.pencil)
            }, title: L10n.Onboarding.ManualUrlEntry.title, primaryDescription: "", content: {
                VStack {
                    HATextField(placeholder: L10n.Onboarding.ManualSetup.TextField.placeholder, text: $urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .focused($focused, equals: true)
                        .onAppear {
                            focused = true
                        }

                    httpOrHttpsSection
                }
            }, primaryActionTitle: L10n.Onboarding.ManualUrlEntry.PrimaryAction.title) {
                guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                if let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    dismiss()
                    connectAction(url)
                } else {
                    showInvalidURLError = true
                }
            }
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
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
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                Text(L10n.Onboarding.ManualSetup.HelperSection.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, DesignSystem.Spaces.two)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(URLScheme.allCases, id: \.rawValue) { scheme in
                    Button(action: {
                        urlString = scheme.rawValue + urlString
                    }, label: {
                        Text(verbatim: scheme.rawValue + urlString)
                    })
                    .frame(alignment: .leading)
                }
            }
            .buttonStyle(.outlinedButton)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            ManualURLEntryView { _ in
            }
        }
}
