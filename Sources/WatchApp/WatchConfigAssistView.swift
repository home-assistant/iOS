import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

/// Configure the watch Assist button (whether it shows, and which server + pipeline it uses) directly
/// on the watch. Self-contained: it reads the current config and the available pipelines from the
/// local mirrored database (refreshable from the paired iPhone via Reload), and persists via the
/// shared `watchConfigUpdate` round-trip.
struct WatchConfigAssistView: View {
    @StateObject private var viewModel = WatchConfigAssistViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Toggle(isOn: $viewModel.showAssist) {
                    Text(verbatim: L10n.Watch.Config.Assist.show)
                }
            }

            if viewModel.showAssist {
                if viewModel.servers.count > 1 {
                    Section {
                        Picker(L10n.Watch.Config.Assist.selectServer, selection: $viewModel.selectedServerId) {
                            ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                                Text(verbatim: server.info.name)
                                    .tag(Optional(server.identifier.rawValue))
                            }
                        }
                        .onChange(of: viewModel.selectedServerId) { _ in
                            viewModel.selectedPipelineId = nil
                            viewModel.loadPipelines()
                        }
                    }
                }

                Section {
                    if !viewModel.pipelines.isEmpty {
                        Picker(L10n.Watch.Config.Assist.pipeline, selection: $viewModel.selectedPipelineId) {
                            Text(verbatim: L10n.Watch.Config.Assist.preferred)
                                .tag(Optional(""))
                            ForEach(viewModel.pipelines) { pipeline in
                                Text(verbatim: pipeline.name)
                                    .tag(Optional(pipeline.id))
                            }
                        }
                    } else if !viewModel.isLoadingPipelines {
                        Text(verbatim: L10n.Watch.Config.Assist.noPipelines)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    reloadButton
                }
            }

            Section {
                Button {
                    viewModel.save { success in
                        if success { dismiss() }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text(verbatim: L10n.Watch.Config.Assist.save)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Config.Assist.title))
        .onAppear {
            if viewModel.showAssist {
                viewModel.loadPipelines()
            }
        }
        .onChange(of: viewModel.showAssist) { isOn in
            if isOn, viewModel.pipelines.isEmpty {
                viewModel.loadPipelines()
            }
        }
        .alert(
            Text(verbatim: L10n.Watch.Config.Assist.title),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(verbatim: errorMessage)
            }
        }
    }

    private var reloadButton: some View {
        Button {
            viewModel.refreshFromPhone()
        } label: {
            HStack {
                if viewModel.isLoadingPipelines {
                    ProgressView()
                } else {
                    Label(L10n.Watch.Config.Assist.reload, systemSymbol: .arrowClockwise)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .disabled(viewModel.isLoadingPipelines)
    }
}
