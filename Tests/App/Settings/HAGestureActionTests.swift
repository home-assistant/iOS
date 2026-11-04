import Foundation
@testable import Shared
import Testing

struct HAGestureActionTests {
    @Test func testCreateDeeplinkBelongsToPageCategory() {
        #expect(HAGestureAction.createDeeplink.category == .page)
    }

    @Test func testCreateDeeplinkPresentation() {
        #expect(HAGestureAction.createDeeplink.localizedString == L10n.Gestures.Value.Option.createDeeplink)
        #expect(HAGestureAction.createDeeplink.moreInfo == L10n.Gestures.Value.Option.MoreInfo.createDeeplink)
        #expect(HAGestureAction.createDeeplink.icon == .link)
    }

    @Test func testUnknownActionDecodesAsNone() throws {
        let data = try #require("\"somethingRemoved\"".data(using: .utf8))
        let decoded = try JSONDecoder().decode(HAGestureAction.self, from: data)

        #expect(decoded == .none)
    }
}
