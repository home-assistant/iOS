import Shared
import SwiftUI

@available(iOS 26.0, *)
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(server: server))
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemSymbol: .exclamationmarkTriangle)
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if viewModel.groupedEntities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemSymbol: .house)
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No entities found")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(
                            alignment: .leading,
                            spacing: DesignSystem.Spaces.three
                        ) {
                            ForEach(viewModel.groupedEntities) { section in
                                Section {
                                    entityTilesGrid(for: section.entities)
                                } header: {
                                    sectionHeader(section.name)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Home")
            .navigationTitle("Connected")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemSymbol: .safari)
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemSymbol: .gearshape)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        /* no-op */
                    } label: {
                        Image(systemSymbol: .listDash)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await viewModel.loadEntities()
            }
        }
        .navigationViewStyle(.stack)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
    }

    private func entityTilesGrid(for entities: [HAAppEntity]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(entities) { entity in
                EntityTileView(entity: entity)
            }
        }
    }
}

#Preview {
    HomeView(server: ServerFixture.standard)
}
