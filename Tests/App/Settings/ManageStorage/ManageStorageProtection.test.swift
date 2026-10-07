@testable import HomeAssistant
import Testing

struct ManageStorageProtectionTests {
    @Test func deletableCarriesNoReason() {
        #expect(ManageStorageProtection.deletable.isDeletable)
        #expect(ManageStorageProtection.deletable.reason == nil)
    }

    @Test func everyProtectionReasonBlocksDeletionAndExplainsItself() {
        for reason in ManageStorageProtectionReason.allCases {
            let protection = ManageStorageProtection.protected(reason)

            #expect(!protection.isDeletable, "\(reason.rawValue) should not be deletable")
            #expect(protection.reason == reason)
            #expect(!reason.explanation.isEmpty, "missing explanation for \(reason.rawValue)")
        }
    }

    @Test func protectionReasonExplanationsAreUnique() {
        let explanations = Set(ManageStorageProtectionReason.allCases.map(\.explanation))

        #expect(explanations.count == ManageStorageProtectionReason.allCases.count)
    }
}
