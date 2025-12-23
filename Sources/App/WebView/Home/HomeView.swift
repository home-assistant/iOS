import Shared
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedServerId: String?
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

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
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                if let serverId = selectedServerId ?? Current.servers.all.first?.identifier.rawValue {
                    await viewModel.loadEntities(for: serverId)
                }
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
    HomeView()
}
