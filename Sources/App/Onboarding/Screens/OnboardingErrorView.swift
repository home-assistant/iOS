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
            Text(L10n.Onboarding.ConnectionError.title)
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
                    openURL(documentationURL(for: error))
                }
            }
        }
        .onAppear {
            viewAppeared = true
        }
        .sheet(isPresented: $showShareSheet, content: {
            ActivityView(activityItems: [Current.Log.archiveURL()])
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
            }
        }
        .padding()
    }

    private func errorCode(_ value: String) -> NSAttributedString {
        NSAttributedString(string: L10n.Onboarding.ConnectionTestResult.errorCode + "\n" + value)
    }

    @ViewBuilder
    private var exportLogsView: some View {
        if #available(iOS 16.0, *) {
            if let archiveURL = Current.Log.archiveURL() {
                ShareLink(item: archiveURL, label: {
                    Text(Current.Log.exportTitle)
                })
            }
        } else {
            Button(Current.Log.exportTitle) {
                showShareSheet = true
            }
        }
    }

    private func documentationURL(for error: Error) -> URL {
        var string = "https://companion.home-assistant.io/docs/troubleshooting/errors"

        if let error = error as? OnboardingAuthError {
            string += "#\(error.kind.documentationAnchor)"
        }

        return URL(string: string)!
    }
}

#Preview {
    OnboardingErrorView(error: HAError.internal(debugDescription: ""))
}
