import Shared
import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedServerId: String?
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewControllerProvider = ViewControllerProvider()

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
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label(L10n.Settings.NavigationBar.title, systemSymbol: .gearshape)
                        }
                        
                        if Current.servers.all.count > 1 {
                            Divider()
                            
                            ForEach(Current.servers.all, id: \.identifier) { server in
                                Button {
                                    Task {
                                        await viewModel.loadEntities(for: server.identifier.rawValue)
                                        selectedServerId = server.identifier.rawValue
                                    }
                                } label: {
                                    HStack {
                                        Text(server.info.name)
                                        if selectedServerId == server.identifier.rawValue {
                                            Spacer()
                                            Image(systemSymbol: .checkmark)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemSymbol: .gearshape)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(viewControllerProvider)
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

struct EntityTileView: View {
    let entity: HAAppEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                iconView
                VStack(alignment: .leading, spacing: 2) {
                    Text(entity.name)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding([.leading, .trailing], 12)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(Color.tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.tileBorder, lineWidth: 1)
        )
    }

    private var iconView: some View {
        let icon = entity.icon.flatMap { MaterialDesignIcons(serversideValueNamed: $0) } ?? .homeIcon
        let iconColor = Color.haPrimary

        return VStack {
            Text(verbatim: icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 20))
                .foregroundColor(iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(width: 38, height: 38)
        .background(iconColor.opacity(0.3))
        .clipShape(Circle())
    }
}

#Preview {
    HomeView()
}
