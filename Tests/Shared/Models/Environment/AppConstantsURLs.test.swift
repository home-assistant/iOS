import Foundation
@testable import Shared
import UIKit
import XCTest

final class AppConstantsURLsTests: XCTestCase {
    private var scheme: String { AppConstants.deeplinkURL.absoluteString }

    func testDeeplinkSchemeFollowsTheBuildConfiguration() {
        switch Current.appConfiguration {
        case .debug:
            XCTAssertEqual(AppConstants.deeplinkURL.absoluteString, "homeassistant-dev://")
        case .fastlaneSnapshot, .release:
            XCTAssertEqual(AppConstants.deeplinkURL.absoluteString, "homeassistant://")
        }
        XCTAssertTrue(AppConstants.deeplinkSchemes.contains(AppConstants.deeplinkURL.scheme ?? ""))
        XCTAssertEqual(AppConstants.createCustomWidgetURL.absoluteString, "\(scheme)createCustomWidget")
    }

    func testNormalizedNavigationDestination() {
        XCTAssertEqual(AppConstants.normalizedNavigationDestination("map/0"), "/map/0")
        XCTAssertEqual(AppConstants.normalizedNavigationDestination("/lovelace/0"), "/lovelace/0")
        XCTAssertEqual(
            AppConstants.normalizedNavigationDestination("https://example.com/page"),
            "https://example.com/page"
        )
        XCTAssertEqual(
            AppConstants.normalizedNavigationDestination("homeassistant://navigate/x"),
            "homeassistant://navigate/x"
        )
    }

    func testInvitationURLEmbedsTheServerURL() throws {
        let url = try XCTUnwrap(AppConstants.invitationURL(serverURL: URL(string: "http://homeassistant.local:8123")!))
        XCTAssertEqual(url.absoluteString, "https://my.home-assistant.io/invite/#url=http://homeassistant.local:8123")
    }

    func testNavigateDeeplinkURL() throws {
        let plain = try XCTUnwrap(AppConstants.navigateDeeplinkURL(
            path: "lovelace/0",
            serverId: "server-1",
            avoidUnnecessaryReload: false
        ))
        XCTAssertEqual(
            plain.absoluteString,
            "\(scheme)navigate/lovelace/0?server=server-1&avoidUnnecessaryReload=false&isComingFromAppIntent=true"
        )

        let withQuery = try XCTUnwrap(AppConstants.navigateDeeplinkURL(
            path: "lovelace/0",
            serverId: "server-1",
            queryParams: "edit=1",
            avoidUnnecessaryReload: true
        ))
        XCTAssertTrue(withQuery.absoluteString.hasSuffix("isComingFromAppIntent=true&edit=1"))
        XCTAssertTrue(withQuery.absoluteString.contains("avoidUnnecessaryReload=true"))
    }

    func testOpenPageAndEntityDeeplinksCarryTheWidgetAuthenticity() throws {
        let page = try XCTUnwrap(AppConstants.openPageDeeplinkURL(path: "energy", serverId: "server-1"))
        XCTAssertTrue(page.absoluteString.hasPrefix("\(scheme)navigate/energy?server=server-1"))
        XCTAssertTrue(page.absoluteString.contains("widgetAuthenticity="))

        let entity = try XCTUnwrap(AppConstants.openEntityDeeplinkURL(entityId: "light.kitchen", serverId: "server-1"))
        XCTAssertTrue(entity.absoluteString.contains("more-info-entity-id=light.kitchen"))
        XCTAssertTrue(entity.absoluteString.contains("widgetAuthenticity="))
        XCTAssertEqual(
            AppConstants.openEntityDestinationURL(entityId: "light.kitchen", serverId: "server-1")?.path,
            entity.path
        )

        let assist = try XCTUnwrap(AppConstants.assistDeeplinkURL(
            serverId: "server-1",
            pipelineId: "pipeline-1",
            startListening: true
        ))
        XCTAssertTrue(assist.absoluteString.hasPrefix(
            "\(scheme)assist?serverId=server-1&pipelineId=pipeline-1&startListening=true"
        ))
    }

    func testMoreInfoAndPageDeeplinksForAServerName() throws {
        let moreInfo = try XCTUnwrap(AppConstants.openEntityMoreInfoDeeplinkURL(
            entityId: "sensor.temperature",
            serverName: "Home"
        ))
        let components = try XCTUnwrap(URLComponents(url: moreInfo, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems, [
            URLQueryItem(name: "more-info-entity-id", value: "sensor.temperature"),
            URLQueryItem(name: "server", value: "Home"),
        ])

        let page = try XCTUnwrap(AppConstants.pageDeeplinkURL(path: "map", serverName: "Home"))
        XCTAssertEqual(page.absoluteString, "\(scheme)navigate/map?server=Home")
    }

    func testTodoAndCalendarURLs() throws {
        XCTAssertNil(AppConstants.todoListAddItemURL(listId: "", serverId: "server-1"))
        XCTAssertNil(AppConstants.todoListAddItemURL(listId: "todo.list", serverId: ""))
        XCTAssertNil(AppConstants.todoListOpenURL(listId: "", serverId: "server-1"))
        XCTAssertNil(AppConstants.calendarOpenURL(serverId: ""))

        let add = try XCTUnwrap(AppConstants.todoListAddItemURL(listId: "todo.list", serverId: "server-1"))
        XCTAssertEqual(add.absoluteString, "\(scheme)navigate/todo?entity_id=todo.list&serverId=server-1&add_item=true")

        let open = try XCTUnwrap(AppConstants.todoListOpenURL(listId: "todo.list", serverId: "server-1"))
        XCTAssertEqual(open.absoluteString, "\(scheme)navigate/todo?entity_id=todo.list&serverId=server-1")

        let allCalendars = try XCTUnwrap(AppConstants.calendarOpenURL(serverId: "server-1", entityId: ""))
        XCTAssertEqual(allCalendars.absoluteString, "\(scheme)navigate/calendar?serverId=server-1")

        let oneCalendar = try XCTUnwrap(AppConstants.calendarOpenURL(serverId: "server-1", entityId: "calendar.family"))
        XCTAssertEqual(
            oneCalendar.absoluteString,
            "\(scheme)navigate/calendar?entity_id=calendar.family&serverId=server-1"
        )
    }

    func testNFCTagURLWrapsTheDeeplink() throws {
        let deeplink = try XCTUnwrap(URL(string: "homeassistant://navigate/lovelace?server=a&b=c"))
        let tagURL = try XCTUnwrap(AppConstants.nfcTagURL(deeplink: deeplink))

        XCTAssertTrue(tagURL.absoluteString.hasPrefix("https://www.home-assistant.io/ios/nfc/?url="))
        let components = try XCTUnwrap(URLComponents(url: tagURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.count, 1)
        XCTAssertEqual(components.queryItems?.first?.value, deeplink.absoluteString)
    }

    func testTintColorsAdaptToTheInterfaceStyle() {
        let dark = AppConstants.tintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = AppConstants.tintColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))

        XCTAssertEqual(dark, AppConstants.lighterTintColor)
        XCTAssertEqual(light, AppConstants.darkerTintColor)
        XCTAssertNotEqual(AppConstants.lighterTintColor, AppConstants.darkerTintColor)
    }

    @MainActor
    func testHelpBarButtonItemIsLabelled() {
        XCTAssertEqual(AppConstants.helpBarButtonItem.accessibilityLabel, L10n.helpLabel)
    }

    func testAppGroupIdentifiersDeriveFromTheBundle() {
        XCTAssertEqual(AppConstants.AppGroupID, "group." + AppConstants.BundleID.lowercased())
        XCTAssertFalse(AppConstants.BundleID.hasSuffix(".Widgets"))
        XCTAssertFalse(AppConstants.BundleID.hasSuffix(".Intents"))
    }

    func testSharedFilesLiveInTheDatabasesDirectory() {
        for file in [AppConstants.appGRDBFile, AppConstants.clientEventsFile, AppConstants.notificationHistoryFile] {
            XCTAssertEqual(file.deletingLastPathComponent().lastPathComponent, "databases")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.deletingLastPathComponent().path))
        }
        XCTAssertEqual(AppConstants.appGRDBFile.lastPathComponent, "App.sqlite")
        XCTAssertEqual(AppConstants.notificationHistoryFile.lastPathComponent, "notificationHistory.json")
    }

    func testCacheLocations() {
        let widgetStates = AppConstants.widgetCachedStates(widgetId: "abc")
        XCTAssertEqual(widgetStates.lastPathComponent, "widgetId-abc.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: AppConstants.widgetsCacheURL.path))

        let magicItems = AppConstants.watchMagicItemsInfo
        XCTAssertEqual(magicItems.lastPathComponent, "magicItemsInfo.json")
        XCTAssertEqual(magicItems.deletingLastPathComponent().lastPathComponent, "caches")

        let downloads = AppConstants.DownloadsDirectory
        XCTAssertEqual(downloads.lastPathComponent, "Downloads")
        XCTAssertTrue(FileManager.default.fileExists(atPath: downloads.path))
    }

    func testClientVersionCarriesTheBuild() {
        let version = AppConstants.clientVersion
        XCTAssertEqual(version.build, AppConstants.build)
    }

    func testCoreRequiredString() {
        XCTAssertEqual(Version.canNavigateThroughFrontend.coreRequiredString, L10n.requiresVersion("core-2025.6"))
    }
}
