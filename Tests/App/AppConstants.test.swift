import Foundation
import Shared
import Testing

struct AppConstantsTests {
    @Test func testInvitationURL() async throws {
        let serverURL = URL(string: "https://demo.home-assistant.io")!
        let expected = "https://my.home-assistant.io/invite/#url=https://demo.home-assistant.io"
        let result = AppConstants.invitationURL(serverURL: serverURL)?.absoluteString
        assert(result == expected, "Expected \(expected), got \(String(describing: result))")
    }

    @Test func testWebURLs() async throws {
        assert(AppConstants.WebURLs.homeAssistant.absoluteString == "https://www.home-assistant.io")
        assert(
            AppConstants.WebURLs.homeAssistantGetStarted
                .absoluteString == "https://www.home-assistant.io/installation/"
        )
        assert(AppConstants.WebURLs.companionAppDocs.absoluteString == "https://companion.home-assistant.io")
        assert(
            AppConstants.WebURLs.companionAppDocsTroubleshooting
                .absoluteString == "https://companion.home-assistant.io/docs/troubleshooting/errors"
        )
        assert(AppConstants.WebURLs.beta.absoluteString == "https://companion.home-assistant.io/app/ios/beta")
        assert(AppConstants.WebURLs.betaMac.absoluteString == "https://companion.home-assistant.io/app/ios/beta_mac")
        assert(AppConstants.WebURLs.review.absoluteString == "https://companion.home-assistant.io/app/ios/review")
        assert(
            AppConstants.WebURLs.reviewMac
                .absoluteString == "https://companion.home-assistant.io/app/ios/review_mac"
        )
        assert(AppConstants.WebURLs.translate.absoluteString == "https://companion.home-assistant.io/app/ios/translate")
        assert(AppConstants.WebURLs.forums.absoluteString == "https://community.home-assistant.io/")
        assert(AppConstants.WebURLs.chat.absoluteString == "https://companion.home-assistant.io/app/ios/chat")
        assert(AppConstants.WebURLs.twitter.absoluteString == "https://twitter.com/home_assistant")
        assert(AppConstants.WebURLs.facebook.absoluteString == "https://www.facebook.com/292963007723872")
        assert(AppConstants.WebURLs.repo.absoluteString == "https://companion.home-assistant.io/app/ios/repo")
        assert(AppConstants.WebURLs.issues.absoluteString == "https://companion.home-assistant.io/app/ios/issues")
        assert(
            AppConstants.WebURLs.companionAppConnectionSecurityLevel
                .absoluteString == "https://companion.home-assistant.io/docs/getting_started/connection-security-level"
        )
        assert(
            AppConstants.WebURLs.companionLocalPush
                .absoluteString == "https://companion.home-assistant.io/app/ios/local-push"
        )
        assert(
            AppConstants.WebURLs.nfcDocs
                .absoluteString == "https://companion.home-assistant.io/app/ios/nfc"
        )
    }

    @Test func testQueryItemsRawValues() async throws {
        assert(AppConstants.QueryItems.openMoreInfoDialog.rawValue == "more-info-entity-id")
        assert(AppConstants.QueryItems.isComingFromAppIntent.rawValue == "isComingFromAppIntent")
    }

    @Test func testOpenEntityDeeplinkURL() async throws {
        let entityId = "light.living_room"
        let serverId = "server123"
        let result = AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId)?.absoluteString

        // Verify the URL contains empty path (navigate/?) and correct query params
        assert(result?.contains("navigate/?") == true, "URL should contain navigate/? with empty path")
        assert(
            result?.contains("more-info-entity-id=\(entityId)") == true,
            "URL should contain more-info-entity-id query parameter"
        )
        assert(result?.contains("server=\(serverId)") == true, "URL should contain server query parameter")
        assert(
            result?.contains("avoidUnecessaryReload=true") == true,
            "URL should contain avoidUnecessaryReload=true"
        )
        assert(
            result?.contains("isComingFromAppIntent=true") == true,
            "URL should contain isComingFromAppIntent=true"
        )
    }

    @available(iOS 16.0, *)
    @Test func testTodoListAddItemURL() async throws {
        let listId = "todo.shopping_list"
        let serverId = "server123"
        let url = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId)
        assert(url != nil, "Expected URL to be created for valid listId and serverId")

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        assert(components?.scheme == AppConstants.deeplinkURL.scheme, "URL should use the app deeplink scheme")
        assert(components?.host == "navigate", "URL host should be navigate")
        assert(components?.path == "/todo", "URL path should be /todo")

        let queryItems = components?.queryItems ?? []
        let queryValues = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        assert(queryValues["entity_id"] == listId, "URL should include entity_id query item")
        assert(queryValues["serverId"] == serverId, "URL should include serverId query item")
    }
}
