import Security
import SFSafeSymbols
import Shared
import SwiftUI

struct KeychainExplorerView: View {
    @State private var sections: [KeychainSection] = []
    @State private var loadError: String?

    var body: some View {
        List {
            if let loadError {
                Section {
                    Text(loadError)
                        .foregroundStyle(.red)
                }
            }

            if sections.isEmpty, loadError == nil {
                Section {
                    Text(L10n.Settings.Debugging.KeychainExplorer.emptyState)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sections) { section in
                    Section(
                        header: Text(section.serviceName),
                        footer: Text(L10n.Settings.Debugging.KeychainExplorer.itemCountFormat(section.items.count))
                    ) {
                        ForEach(section.items) { item in
                            NavigationLink {
                                KeychainItemDetailView(item: item)
                            } label: {
                                KeychainExplorerRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.Debugging.KeychainExplorer.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadItems()
        }
    }

    private func loadItems() {
        do {
            let items = try KeychainGenericPasswordItem.loadAll()
            let groupedItems = Dictionary(grouping: items, by: \.serviceName)
            sections = groupedItems.keys.sorted().map { serviceName in
                KeychainSection(
                    serviceName: serviceName,
                    items: groupedItems[serviceName, default: []].sorted {
                        $0.account.localizedCaseInsensitiveCompare($1.account) == .orderedAscending
                    }
                )
            }
            loadError = nil
        } catch {
            sections = []
            loadError = L10n.Settings.Debugging.KeychainExplorer.loadErrorFormat(error.localizedDescription)
            Current.Log.error("Failed to load keychain items: \(error)")
        }
    }
}

private struct KeychainExplorerRow: View {
    let item: KeychainGenericPasswordItem

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .key)
                .foregroundStyle(Color.haPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                Text(item.account)
                    .foregroundStyle(Color(uiColor: .label))

                Text(item.valueSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct KeychainItemDetailView: View {
    let item: KeychainGenericPasswordItem

    var body: some View {
        List {
            Section(L10n.Settings.Debugging.KeychainExplorer.metadataSection) {
                detailRow(title: L10n.Settings.Debugging.KeychainExplorer.serviceLabel, value: item.serviceName)
                detailRow(title: L10n.Settings.Debugging.KeychainExplorer.accountLabel, value: item.account)
                detailRow(
                    title: L10n.Settings.Debugging.KeychainExplorer.accessGroupLabel,
                    value: item.accessGroup ?? L10n.Settings.Debugging.KeychainExplorer.noneValue
                )
                detailRow(
                    title: L10n.Settings.Debugging.KeychainExplorer.accessibilityLabel,
                    value: item.accessibility ?? L10n.Settings.Debugging.KeychainExplorer.unknownValue
                )
                detailRow(
                    title: L10n.Settings.Debugging.KeychainExplorer.sizeLabel,
                    value: L10n.Settings.Debugging.KeychainExplorer.bytesFormat(item.data.count)
                )
            }

            Section(L10n.Settings.Debugging.KeychainExplorer.valueSection) {
                Text(item.renderedValue)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(item.account)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct KeychainSection: Identifiable {
    let serviceName: String
    let items: [KeychainGenericPasswordItem]

    var id: String { serviceName }
}

private struct KeychainGenericPasswordItem: Identifiable {
    let serviceName: String
    let account: String
    let accessGroup: String?
    let accessibility: String?
    let data: Data

    var id: String {
        "\(serviceName)::\(account)"
    }

    var valueSummary: String {
        if let stringValue = normalizedStringValue {
            return stringValue.replacingOccurrences(of: "\n", with: " ")
        }

        return L10n.Settings.Debugging.KeychainExplorer.base64Prefix(data.base64EncodedString())
    }

    var renderedValue: String {
        if let prettyJSONValue {
            return prettyJSONValue
        }

        if let stringValue = normalizedStringValue {
            return stringValue
        }

        return data.base64EncodedString()
    }

    private var normalizedStringValue: String? {
        guard let stringValue = String(data: data, encoding: .utf8) else {
            return nil
        }

        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? stringValue : trimmedValue
    }

    private var prettyJSONValue: String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }

        return prettyString
    }

    static func loadAll() throws -> [KeychainGenericPasswordItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let attributesList = result as? [[String: Any]] else {
                return []
            }

            return attributesList.compactMap { attributes in
                guard
                    let serviceName = attributes[kSecAttrService as String] as? String,
                    let account = attributes[kSecAttrAccount as String] as? String,
                    let data = attributes[kSecValueData as String] as? Data else {
                    return nil
                }

                return KeychainGenericPasswordItem(
                    serviceName: serviceName,
                    account: account,
                    accessGroup: attributes[kSecAttrAccessGroup as String] as? String,
                    accessibility: attributes[kSecAttrAccessible as String] as? String,
                    data: data
                )
            }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainExplorerError(status: status)
        }
    }
}

private struct KeychainExplorerError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }

        return L10n.Settings.Debugging.KeychainExplorer.queryErrorFormat(status)
    }
}

#Preview {
    NavigationView {
        KeychainExplorerView()
    }
}
