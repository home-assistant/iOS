import PromiseKit
import Shared
import SwiftUI

struct NotificationDebugView: View {
    @StateObject private var viewModel = NotificationDebugViewModel()

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var resetAlert: ResetAlertInfo?
    @State private var ratePromise: Promise<RateLimitResponse>?
    @State private var rateLimitRemaining: Int?

    private struct ResetAlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        GroupedList {
            Section {
                NavigationLink {
                    NotificationRateLimitView(initialPromise: ratePromise) { response in
                        rateLimitRemaining = response.rateLimits.remaining
                    }
                } label: {
                    HStack {
                        Text(L10n.SettingsDetails.Notifications.RateLimits.header)
                        Spacer()
                        if let remaining = rateLimitRemaining {
                            Text(NumberFormatter.localizedString(from: NSNumber(value: remaining), number: .decimal))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                NavigationLink {
                    NotificationDebugNotificationsView()
                } label: {
                    Text(L10n.SettingsDetails.Location.Notifications.header)
                }

                #if os(macOS)
                if let pushID = viewModel.pushID {
                    ShareLink(item: pushID) {
                        pushIDLabel
                    }
                } else {
                    pushIDLabel
                }
                #else
                Button {
                    guard let id = viewModel.pushID else { return }
                    shareItems = [id]
                    showShareSheet = true
                } label: {
                    pushIDLabel
                }
                #endif

                Button {
                    viewModel.resetPushID { result in
                        switch result {
                        case .success:
                            break
                        case let .failure(error):
                            resetAlert = ResetAlertInfo(
                                title: L10n.errorLabel,
                                message: error.localizedDescription
                            )
                        }
                    }
                } label: {
                    Text(L10n.Settings.ResetSection.ResetRow.title)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ratePromise == nil {
                let promise = NotificationRateLimitViewModel.newPromise()
                promise.done { response in
                    rateLimitRemaining = response.rateLimits.remaining
                }.cauterize()
                ratePromise = promise
            }
        }
        #if !os(macOS)
        .sheet(isPresented: $showShareSheet) {
            NotificationsShareSheet(activityItems: shareItems)
        }
        #endif
        .alert(item: $resetAlert) { info in
            Alert(
                title: Text(info.title),
                message: Text(info.message),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
    }

    private var pushIDLabel: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(L10n.SettingsDetails.Notifications.PushIdSection.header)
                .foregroundColor(.primary)
            Text(viewModel.pushIDDisplay)
                .foregroundColor(.secondary)
                .font(.footnote)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    NotificationDebugView()
}
