import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

struct OnboardingErrorView: View {
    @Environment(\.openURL) private var openURL
    @State private var viewAppeared: Bool = false
    @State private var showShareSheet: Bool = false

    let error: Error

    var body: some View {
        VStack(spacing: Spaces.two) {
            Text(verbatim: L10n.Onboarding.ConnectionError.title)
                .font(.title.bold())
            Image(systemSymbol: .xmarkCircleFill)
                .font(.system(size: 60))
                .foregroundStyle(.white, .red)
            ScrollView {
                errorContent
            }
            VStack {
                exportLogsView
                Button(L10n.Onboarding.ConnectionError.moreInfoButton) {
                    if let url = documentationURL(for: error) {
                        openURL(url)
                    } else {
                        Current.Log.error("Failed to create documentation URL for error: \(error)")
                    }
                }
                .buttonStyle(.secondaryButton)
            }
        }
        .onAppear {
            viewAppeared = true
        }
        .sheet(isPresented: $showShareSheet, content: {
            ShareActivityView(activityItems: [Current.Log.archiveURL()])
        })
    }

    private var errorContent: some View {
        var errorComponents: [NSAttributedString] = [
            NSAttributedString(string: error.localizedDescription),
        ]

        if let error = error as? OnboardingAuthError {
            if let code = error.errorCode {
                errorComponents.append(errorCode(code))
            }

            if let source = error.responseString {
                let font: UIFont

                font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)

                errorComponents.append(NSAttributedString(
                    string: source,
                    attributes: [.font: font]
                ))
            }
        } else {
            let nsError = error as NSError
            errorComponents.append(errorCode(String(format: "%@ %d", nsError.domain, nsError.code)))
        }

        return VStack {
            ForEach(errorComponents, id: \.self) { error in
                Text(AttributedString(error))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private func errorCode(_ value: String) -> NSAttributedString {
        NSAttributedString(string: L10n.Onboarding.ConnectionTestResult.errorCode + "\n" + value)
    }

    @ViewBuilder
    private var exportLogsView: some View {
        Group {
            if #available(iOS 16.0, *), let archiveURL = Current.Log.archiveURL() {
                ShareLink(item: archiveURL, label: {
                    Text(Current.Log.exportTitle)
                })
            } else {
                Button(Current.Log.exportTitle) {
                    showShareSheet = true
                }
            }
        }
        .buttonStyle(.primaryButton)
        .padding(.horizontal)
    }

    private func documentationURL(for error: Error) -> URL? {
        var string = AppConstants.WebURLs.companionAppDocsTroubleshooting.absoluteString

        if let error = error as? OnboardingAuthError {
            string += "#\(error.kind.documentationAnchor)"
        }

        return URL(string: string)
    }
}

#Preview {
    OnboardingErrorView(error: HAError.internal(debugDescription: ""))
}
