import RealmSwift
import Shared
import SwiftUI

/// SwiftUI replacement for `NotificationCategoryListViewController`.
///
/// Shows local and server-controlled notification categories in separate
/// sections, supports inserting / deleting local categories, and navigates to
/// `NotificationCategoryEditorView` for editing. The server-controlled section
/// is observed via a Realm notification token through `RealmResultsObserver`.
struct NotificationCategoryListView: View {
    @StateObject private var localCategories = RealmResultsObserver<NotificationCategory>(
        collection: AnyRealmCollection(
            Current.realm().objects(NotificationCategory.self)
                .filter("isServerControlled == NO")
                .sorted(byKeyPath: "Identifier")
        )
    )

    @StateObject private var serverCategories = RealmResultsObserver<NotificationCategory>(
        collection: AnyRealmCollection(
            Current.realm().objects(NotificationCategory.self)
                .filter("isServerControlled == YES")
                .sorted(byKeyPath: "Identifier")
        )
    )

    @State private var editingCategory: NotificationCategory?
    @State private var showingNewCategory = false

    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider

    var body: some View {
        List {
            localSection
            serverSection
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.Categories.header)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openHelp()
                } label: {
                    Image(systemSymbol: .questionmarkCircle)
                }
            }
        }
        .sheet(isPresented: $showingNewCategory) {
            editorSheet(for: nil)
                .environmentObject(viewControllerProvider)
        }
        .sheet(item: $editingCategory) { category in
            editorSheet(for: category)
                .environmentObject(viewControllerProvider)
        }
    }

    // MARK: - Sections

    private var localSection: some View {
        Section(header: Text(L10n.SettingsDetails.Notifications.Categories.header)) {
            ForEach(localCategories.items, id: \.Identifier) { category in
                Button {
                    editingCategory = category
                } label: {
                    HStack {
                        Text(category.Name.isEmpty ? category.Identifier : category.Name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemSymbol: .chevronRight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteLocal)

            Button {
                showingNewCategory = true
            } label: {
                Label(L10n.addButtonLabel, systemSymbol: .plus)
            }
        }
    }

    private var serverSection: some View {
        Section(
            header: Text(L10n.SettingsDetails.Notifications.CategoriesSynced.header),
            footer: Text(
                serverCategories.items.isEmpty
                    ? L10n.SettingsDetails.Notifications.CategoriesSynced.footerNoCategories
                    : L10n.SettingsDetails.Notifications.CategoriesSynced.footer
            )
        ) {
            if serverCategories.items.isEmpty {
                Text(L10n.SettingsDetails.Notifications.CategoriesSynced.empty)
                    .foregroundColor(.secondary)
            } else {
                ForEach(serverCategories.items, id: \.Identifier) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        HStack {
                            Text(category.Name.isEmpty ? category.Identifier : category.Name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemSymbol: .chevronRight)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func deleteLocal(at offsets: IndexSet) {
        let removed = offsets.map { localCategories.items[$0] }
        let identifiers = removed.map(\.Identifier)

        guard !identifiers.isEmpty else { return }

        Current.Log.verbose("Deleting local notification categories: \(identifiers)")

        let realm = Current.realm()
        realm.reentrantWrite {
            realm.delete(realm.objects(NotificationCategory.self).filter("Identifier IN %@", identifiers))
        }
    }

    @ViewBuilder
    private func editorSheet(for category: NotificationCategory?) -> some View {
        NavigationView {
            NotificationCategoryEditorView(category: category) { savedCategory in
                if let saved = savedCategory {
                    let realm = Current.realm()
                    realm.reentrantWrite {
                        realm.add(saved, update: .all)
                    }
                }
                editingCategory = nil
                showingNewCategory = false
            }
        }
        .navigationViewStyle(.stack)
    }

    private func openHelp() {
        guard let url = URL(string: "https://companion.home-assistant.io/app/ios/actionable-notifications") else {
            return
        }
        // Pass the hosting view controller so the SafariInApp browser preference works
        // (it requires a non-nil presenter to show its in-app browser).
        openURLInBrowser(url, viewControllerProvider.viewController)
    }
}

// MARK: - NotificationCategory Identifiable conformance

extension NotificationCategory: Identifiable {
    public var id: String { Identifier }
}
