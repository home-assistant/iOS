import SFSafeSymbols
import Shared
import SwiftUI

/// Explains how the app tells servers apart, what two servers reporting one ID means, and how to
/// give one of them its own ID, listing the servers that report the same ID first. Reached from the
/// onboarding prompt and from the servers list.
struct ServerIdentityExplanationView: View {
    private struct Topic: Identifiable {
        let symbol: SFSymbol
        let title: String
        let body: String

        var id: String { title }
    }

    /// Each group is a set of servers reporting one instance ID between them.
    let conflictingServers: [[ServerIdentityConflictingServer]]

    private static let topics: [Topic] = [
        Topic(
            symbol: .checkmarkSeal,
            title: L10n.ServerIdentity.About.OneEntry.title,
            body: L10n.ServerIdentity.About.OneEntry.body
        ),
        Topic(
            symbol: .docOnDoc,
            title: L10n.ServerIdentity.About.SameId.title,
            body: L10n.ServerIdentity.About.SameId.body
        ),
        Topic(
            symbol: .wrenchAndScrewdriver,
            title: L10n.ServerIdentity.About.Fix.title,
            body: L10n.ServerIdentity.About.Fix.body
        ),
    ]

    var body: some View {
        List {
            ForEach(conflictingServers, id: \.self) { group in
                Section {
                    ForEach(group) { server in
                        HStack(spacing: DesignSystem.Spaces.two) {
                            Image(systemSymbol: .serverRack)
                                .font(.title3)
                                .foregroundStyle(.haPrimary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(server.name)
                                    .font(.headline)
                                if let address = server.address {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, DesignSystem.Spaces.half)
                    }
                } header: {
                    Text(L10n.ServerIdentity.About.Conflicting.header)
                }
            }
            ForEach(Self.topics) { topic in
                Section {
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: topic.symbol)
                            .font(.title3)
                            .foregroundStyle(.haPrimary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(topic.title)
                                .font(.headline)
                            Text(topic.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spaces.half)
                }
            }
        }
        .navigationTitle(L10n.ServerIdentity.About.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ServerIdentityExplanationView(conflictingServers: [[
            ServerIdentityConflictingServer(name: "Home", address: "http://homeassistant.local:8123"),
            ServerIdentityConflictingServer(name: "Chalet", address: "http://chalet.example.com:8123"),
        ]])
    }
}
