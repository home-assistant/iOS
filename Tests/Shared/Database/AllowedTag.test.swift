import GRDB
@testable import Shared
import Testing

@Suite(.serialized)
struct AllowedTagTests {
    private let legacyAllowedTagsKey = "allowedTags"

    @Test("Allowed tags can be added, listed, deleted, and cleared")
    func allowedTagsCRUD() throws {
        try withAllowedTagDatabase {
            AllowedTag.add("garage")
            AllowedTag.add("front-door")
            AllowedTag.add("garage")
            AllowedTag.add("")

            #expect(AllowedTag.contains("garage"))
            #expect(AllowedTag.contains("front-door"))
            #expect(!AllowedTag.contains("missing"))
            #expect(AllowedTag.all().map(\.tag) == ["front-door", "garage"])

            AllowedTag.delete("front-door")

            #expect(!AllowedTag.contains("front-door"))
            #expect(AllowedTag.all().map(\.tag) == ["garage"])

            AllowedTag.clearAll()

            #expect(AllowedTag.all().isEmpty)
        }
    }

    @Test("Allowed tags migrate from legacy UserDefaults storage")
    func migratesLegacyUserDefaultsTags() throws {
        try withAllowedTagDatabase(legacyTags: ["garage", "front-door", "garage", ""]) {
            #expect(AllowedTag.all().map(\.tag) == ["front-door", "garage"])
            #expect(Current.settingsStore.prefs.stringArray(forKey: legacyAllowedTagsKey) == nil)
        }
    }

    private func withAllowedTagDatabase(
        legacyTags: [String]? = nil,
        perform work: () throws -> Void
    ) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        if let legacyTags {
            Current.settingsStore.prefs.set(legacyTags, forKey: legacyAllowedTagsKey)
        }

        try AllowedTagTable().createIfNeeded(database: database)
        Current.database = { database }

        defer {
            Current.database = previousDatabase
            Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        }

        try work()
    }
}
