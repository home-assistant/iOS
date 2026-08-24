@testable import HomeAssistant
@testable import Shared
import Testing

struct AppMigrationRoleTests {
    /// Holds however the two identifiers are eventually chosen. It matters most when the new app's
    /// identifier extends the old one's — as the placeholder does — because a plain source-prefix
    /// test would then classify the new app as the app being replaced and leave the import flow
    /// permanently unreachable.
    @Test func readsTheDestinationFromItsOwnIdentifier() {
        #expect(AppMigrationRole.role(forBundleID: AppMigrationConstants.destinationBundleID) == .destination)
    }

    /// The specific trap, stated without depending on what the constants happen to be today.
    @Test func prefersTheDestinationWhenOneIdentifierExtendsTheOther() {
        let extended = AppMigrationConstants.destinationBundleID + ".beta"

        #expect(AppMigrationRole.role(forBundleID: extended) == .destination)
    }

    @Test func readsTheSourceFromItsOwnIdentifier() {
        #expect(AppMigrationRole.role(forBundleID: AppMigrationConstants.sourceBundleID) == .source)
    }

    /// Development builds append a suffix, so the source has to match by prefix rather than exactly.
    @Test func readsTheSourceFromADevelopmentIdentifier() {
        #expect(AppMigrationRole.role(forBundleID: AppMigrationConstants.sourceBundleID + ".dev") == .source)
    }

    @Test func treatsAnUnrelatedIdentifierAsTheDestination() {
        #expect(AppMigrationRole.role(forBundleID: "com.example.something") == .destination)
    }
}
