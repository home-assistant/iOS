import Shared
import SwiftUI

/// Logs this Apple Watch in to a server on its own, giving it a session separate from the iPhone's.
struct WatchServerLoginView: View {
    @StateObject private var viewModel: WatchServerLoginViewModel
    @Environment(\.dismiss) private var dismiss

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: WatchServerLoginViewModel(server: server))
    }

    init(viewModel: WatchServerLoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            switch viewModel.state {
            case .loading, .loggedIn:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case let .chooseProvider(providers):
                Section(header: Text(verbatim: L10n.Watch.Settings.Login.providerHeader)) {
                    ForEach(providers, id: \.self) { provider in
                        Button {
                            Task { await viewModel.choose(provider) }
                        } label: {
                            Text(verbatim: provider.name)
                        }
                    }
                }
            case let .form(step):
                Section {
                    ForEach(step.dataSchema, id: \.name) { field in
                        let label = WatchServerLoginViewModel.label(for: field)
                        switch field.type {
                        case "boolean":
                            Toggle(isOn: boolBinding(for: field.name)) {
                                Text(verbatim: label)
                            }
                        case "select":
                            Picker(selection: textBinding(for: field.name)) {
                                ForEach(field.options, id: \.value) { option in
                                    Text(verbatim: option.label).tag(option.value)
                                }
                            } label: {
                                Text(verbatim: label)
                            }
                        default:
                            if field.name == "password" {
                                SecureField(label, text: textBinding(for: field.name))
                            } else {
                                TextField(label, text: textBinding(for: field.name))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                } footer: {
                    if let formError = viewModel.formError {
                        Text(verbatim: formError)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(verbatim: L10n.Watch.Settings.Login.logIn)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                    Button {
                        Task { await viewModel.start() }
                    } label: {
                        Text(verbatim: L10n.Watch.Settings.Login.startOver)
                    }
                    .disabled(viewModel.isSubmitting)
                }
            case let .failed(message):
                Section {
                    Text(verbatim: message)
                    Button {
                        Task { await viewModel.start() }
                    } label: {
                        Text(verbatim: L10n.Watch.Settings.Login.retry)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Login.logIn))
        .task {
            if viewModel.state == .loading {
                await viewModel.start()
            }
        }
        .onChange(of: viewModel.state) { state in
            if state == .loggedIn {
                dismiss()
            }
        }
    }

    private func textBinding(for name: String) -> Binding<String> {
        Binding(
            get: { viewModel.textValues[name] ?? "" },
            set: { viewModel.textValues[name] = $0 }
        )
    }

    private func boolBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.boolValues[name] ?? false },
            set: { viewModel.boolValues[name] = $0 }
        )
    }
}

#Preview {
    NavigationView {
        WatchServerLoginView(viewModel: WatchServerLoginViewModel(
            server: ServerFixture.standard,
            previewState: .form(LoginFlowStep(
                kind: .form,
                flowID: "preview",
                stepID: "init",
                dataSchema: [
                    LoginFlowField(name: "username", type: "string"),
                    LoginFlowField(name: "password", type: "string"),
                ],
                errors: ["base": "invalid_auth"]
            ))
        ))
    }
}
