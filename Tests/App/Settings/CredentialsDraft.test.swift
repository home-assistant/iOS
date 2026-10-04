@testable import HomeAssistant
@testable import Shared
import Testing

/// A credentials setting is edited as a draft, so nothing reaches the sensor until Save is tapped.
struct CredentialsDraftTests {
    private final class Store {
        var username = "kiosk"
        var password = "secret"
    }

    private func makeDraft(store: Store) -> CredentialsDraft {
        CredentialsDraft(fields: [
            .init(title: "Username", getter: { store.username }, setter: { store.username = $0 }),
            .init(
                title: "Password",
                isSecure: true,
                getter: { store.password },
                setter: { store.password = $0 }
            ),
        ])
    }

    @Test func startsFromTheStoredValuesWithNothingToSave() {
        let draft = makeDraft(store: Store())

        #expect(draft.values == ["kiosk", "secret"])
        #expect(draft.hasChanges == false)
    }

    @Test func editingAFieldIsAPendingChangeUntilSaved() {
        let store = Store()
        let draft = makeDraft(store: store)

        draft.values[1] = "new-secret"

        #expect(draft.hasChanges)
        #expect(store.password == "secret")

        draft.save()

        #expect(store.password == "new-secret")
        #expect(store.username == "kiosk")
        #expect(draft.hasChanges == false)
    }

    @Test func aDraftWhoseValuesNoLongerMatchItsFieldsReportsNoChanges() {
        let draft = makeDraft(store: Store())

        draft.values = ["only-one"]

        #expect(draft.hasChanges == false)
    }

    @Test func savingSkipsFieldsWithoutAValue() {
        let store = Store()
        let draft = makeDraft(store: store)

        draft.values = ["admin"]
        draft.save()

        #expect(store.username == "admin")
        #expect(store.password == "secret")
    }
}
