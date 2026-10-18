@testable import HomeAssistant
import XCTest

final class ScenesWindowSizeConfigTests: XCTestCase {
    private var savedFrames: [SceneActivity: Data?] = [:]

    override func setUpWithError() throws {
        try super.setUpWithError()
        for activity in SceneActivity.allCases {
            savedFrames[activity] = prefs.data(forKey: ScenesWindowSizeConfig.key(for: activity))
            prefs.removeObject(forKey: ScenesWindowSizeConfig.key(for: activity))
        }
    }

    override func tearDownWithError() throws {
        for (activity, data) in savedFrames {
            if let data {
                prefs.set(data, forKey: ScenesWindowSizeConfig.key(for: activity))
            } else {
                prefs.removeObject(forKey: ScenesWindowSizeConfig.key(for: activity))
            }
        }
        savedFrames = [:]
        try super.tearDownWithError()
    }

    func testMainWindowKeepsLegacyKeyForBackwardCompatibility() {
        XCTAssertEqual(ScenesWindowSizeConfig.key(for: .webView), "default-scene-latest-system-frame-data")
    }

    func testSecondaryWindowsUseDistinctKeys() {
        XCTAssertNotEqual(
            ScenesWindowSizeConfig.key(for: .assist),
            ScenesWindowSizeConfig.key(for: .webView)
        )
    }

    func testFrameRoundTripsPerActivity() {
        let mainFrame = CGRect(x: 10, y: 20, width: 800, height: 600)
        let assistFrame = CGRect(x: 300, y: 400, width: 420, height: 500)

        ScenesWindowSizeConfig.setLatestSystemFrame(mainFrame, for: .webView)
        ScenesWindowSizeConfig.setLatestSystemFrame(assistFrame, for: .assist)

        XCTAssertEqual(ScenesWindowSizeConfig.latestSystemFrame(for: .webView), mainFrame)
        XCTAssertEqual(ScenesWindowSizeConfig.latestSystemFrame(for: .assist), assistFrame)
    }

    func testSettingFrameForOneActivityDoesNotAffectAnother() {
        ScenesWindowSizeConfig.setLatestSystemFrame(.init(x: 1, y: 2, width: 3, height: 4), for: .assist)

        XCTAssertNil(ScenesWindowSizeConfig.latestSystemFrame(for: .webView))
    }

    func testNilFrameRemovesStoredValue() {
        ScenesWindowSizeConfig.setLatestSystemFrame(.init(x: 1, y: 2, width: 3, height: 4), for: .assist)
        ScenesWindowSizeConfig.setLatestSystemFrame(nil, for: .assist)

        XCTAssertNil(ScenesWindowSizeConfig.latestSystemFrame(for: .assist))
    }
}
