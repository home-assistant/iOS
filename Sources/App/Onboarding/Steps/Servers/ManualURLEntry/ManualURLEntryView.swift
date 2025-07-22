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

    let title: String
    let subtitle: String?
    let primaryButtonTitle: String
    let connectAction: (URL) -> Void

    init(
        title: String,
        subtitle: String? = nil,
        primaryButtonTitle: String,
        connectAction: @escaping (URL) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonTitle = primaryButtonTitle
        self.connectAction = connectAction
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spaces.three) {
                    Image(.Onboarding.setupExternalURL)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: OnboardingConstants.iconSize)
                    Text(title)
                        .font(DesignSystem.Font.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Font.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    HATextField(
                        placeholder: "http://homeassistant.local:8123",
                        text: $urlString,
                        keyboardType: .URL
                    )
                    .focused($focused, equals: true)
                    httpOrHttpsSection

                }
                .padding(.horizontal, DesignSystem.Spaces.two)
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
            .safeAreaInset(edge: .bottom) {
                connectButton
            }
            .onAppear {
                focused = true
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

            VStack(alignment: .leading) {
                Text(L10n.Onboarding.ManualSetup.HelperSection.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(DesignSystem.Font.headline)
                    .foregroundStyle(.secondary)
                Button(action: {
                    urlString = "\(Constants.http)\(urlString)"
                }, label: {
                    Text(verbatim: "\(Constants.http)\(urlString)")
                })
                .buttonStyle(.pillButton)
                Button(action: {
                    urlString = "\(Constants.https)\(urlString)"
                }, label: {
                    Text(verbatim: "\(Constants.https)\(urlString)")
                })
                .buttonStyle(.pillButton)
            }
            .frame(maxWidth: .infinity)
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
            Text(primaryButtonTitle)
        }
        .buttonStyle(.primaryButton)
        .padding()
        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

#Preview {
    VStack {}
        .sheet(isPresented: .constant(true)) {
            ManualURLEntryView(title: "What is your address?", primaryButtonTitle: "Connect") { _ in
            }
        }
}
