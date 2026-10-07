import Shared
import SwiftUI

/// Lists every webhook URL this server can be reached at — the Home Assistant Cloud cloudhook when
/// there is one, plus the URLs the app derives from the server's own internal/remote/external URLs —
/// shows which one is in use right now, and lets each be checked for reachability.
struct WebhookDetailView: View {
    @StateObject private var viewModel: WebhookDetailViewModel

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: WebhookDetailViewModel(server: server))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L10n.Settings.ConnectionSection.Webhook.Active.title)
                    Spacer()
                    Text(viewModel.activeSourceTitle)
                        .foregroundColor(.secondary)
                }

                if let activeURL = viewModel.activeURL {
                    Text(activeURL.absoluteString)
                        .font(.footnote.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .privacySensitive()
                        .screenCaptureProtected()

                    Button {
                        viewModel.copyActiveURL()
                    } label: {
                        Label(L10n.copyLabel, systemSymbol: .docOnDoc)
                    }
                }
            } footer: {
                Text(L10n.Settings.ConnectionSection.Webhook.footer)
            }

            ForEach(Array(viewModel.endpoints.enumerated()), id: \.element.id) { index, endpoint in
                Section {
                    Text(
                        endpoint.url?.absoluteString
                            ?? L10n.Settings.ConnectionSection.Cloudhook.Status.notConfigured
                    )
                    .font(.footnote.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .privacySensitive()
                    .screenCaptureProtected()

                    Button {
                        viewModel.copyURL(of: endpoint)
                    } label: {
                        Label(L10n.copyLabel, systemSymbol: .docOnDoc)
                    }
                    .disabled(endpoint.url == nil)

                    Button {
                        Task {
                            await viewModel.checkReachability(for: endpoint)
                        }
                    } label: {
                        if viewModel.isChecking(endpoint) {
                            ProgressView()
                        } else {
                            Label(
                                L10n.Settings.ConnectionSection.Cloudhook.CheckReachability.title,
                                systemSymbol: .arrowClockwise
                            )
                        }
                    }
                    .disabled(endpoint.url == nil || viewModel.isChecking(endpoint))

                    if let result = viewModel.result(for: endpoint) {
                        HStack {
                            Text(L10n.Settings.ConnectionSection.Cloudhook.CheckReachability.result)
                            Spacer()
                            Text(result.localizedDescription)
                                .foregroundColor(result.isReachable ? .green : .red)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    HStack {
                        Text(endpoint.source.title)
                        if viewModel.activeSource == endpoint.source {
                            Text(L10n.Settings.ConnectionSection.Webhook.inUse)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, DesignSystem.Spaces.one)
                                .padding(.vertical, DesignSystem.Spaces.half)
                                .background(Color.haPrimary.opacity(0.2))
                                .foregroundColor(.haPrimary)
                                .clipShape(Capsule())
                        }
                    }
                } footer: {
                    if index == viewModel.endpoints.count - 1 {
                        Text(L10n.Settings.ConnectionSection.Webhook.Endpoints.footer)
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.ConnectionSection.Webhook.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh()
        }
    }
}

#Preview {
    NavigationView {
        WebhookDetailView(server: ServerFixture.withRemoteConnection)
    }
}
