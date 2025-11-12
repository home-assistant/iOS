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
    }

    @Test func testQueryItemsRawValues() async throws {
        assert(AppConstants.QueryItems.openMoreInfoDialog.rawValue == "more-info-entity-id")
        assert(AppConstants.QueryItems.isComingFromAppIntent.rawValue == "isComingFromAppIntent")
    }
}
