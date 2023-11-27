//
//  ThreadCredentialsSharingView.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

@available(iOS 16.4, *)
struct ThreadCredentialsSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ThreadCredentialsSharingViewModel

    init(viewModel: ThreadCredentialsSharingViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.showLoader {
                   progressView
                } else {
                   credentialsList
                }
            }
            .navigationTitle(L10n.Thread.Credentials.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .secondarySystemBackground))
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(L10n.doneLabel)
                    }
                }
            })
            .alert(alertTitle, isPresented: $viewModel.showAlert) {
                errorAlertActions
            } message: {
                if case .error(_, let message) = viewModel.alertType {
                    Text(message)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.retrieveAllCredentials()
            }
        }
    }

    private var alertTitle: String {
        if case .error(let title, _) = viewModel.alertType {
            return title
        } else if case .success(let title) = viewModel.alertType {
            return title
        } else {
            return ""
        }
    }

    @ViewBuilder
    private var errorAlertActions: some View {
        Button {
            /* no-op */
        } label: {
            Text(L10n.doneLabel)
        }

        if case .error(_, _)  = viewModel.alertType {
            Button {
                Task {
                    await viewModel.retrieveAllCredentials()
                }
            } label: {
                Text(L10n.retryLabel)
            }
        }
    }

    private var progressView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .scaleEffect(CGSize(width: 2, height: 2))
    }

    @ViewBuilder
    private var credentialsList: some View {
        if viewModel.credentials.isEmpty {
            Text("You don't have credentials available on your iCloud Keychain.")
                .multilineTextAlignment(.center)
        } else {
            List(viewModel.credentials, id: \.borderAgentID) { credential in
                makeCredentialCard(credential: credential)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }

    private func makeCredentialCard(credential: ThreadCredential) -> some View {
        CardView(backgroundColor: Color(uiColor: .systemBackground)) {
            makeCardPropertyView(
                title: L10n.Thread.Credentials.networkNameTitle,
                value: credential.networkName
            )
            makeCardPropertyView(
                title: L10n.Thread.Credentials.borderAgentIdTitle,
                value: credential.borderAgentID
            )
            makeCardPropertyView(
                title: L10n.Thread.Credentials.networkKeyTitle,
                value: credential.networkKey
            )
            Button {
                viewModel.shareCredentialWithHomeAssistant(credential: credential)
            } label: {
                Text(L10n.Thread.Credentials.shareCredentialsButtonTitle)
            }
            .buttonStyle(.textButton)
        }
    }

    private func makeCardPropertyView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Group {
                Text(title)
                    .font(.footnote)
                Text(value)
                    .textSelection(.enabled)
                    .font(.body.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
