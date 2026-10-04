#if os(iOS)
import Foundation
@testable import Shared
import XCTest

final class MatterWrapperTests: XCTestCase {
    private var savedServerID: String?

    override func setUp() {
        super.setUp()
        savedServerID = Current.settingsStore.prefs.string(forKey: "lastCommissionServerID")
        Current.settingsStore.prefs.removeObject(forKey: "lastCommissionServerID")
    }

    override func tearDown() {
        Current.settingsStore.prefs.set(savedServerID, forKey: "lastCommissionServerID")
        super.tearDown()
    }

    func testAvailability() {
        let wrapper = MatterWrapper()
        #if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(wrapper.isAvailable)
        #else
        XCTAssertFalse(wrapper.isAvailable)
        #endif
        #if canImport(ThreadNetwork) && !targetEnvironment(macCatalyst)
        XCTAssertTrue(wrapper.threadCredentialsSharingEnabled)
        XCTAssertTrue(wrapper.threadCredentialsStoreInKeychainEnabled)
        #else
        XCTAssertFalse(wrapper.threadCredentialsSharingEnabled)
        XCTAssertFalse(wrapper.threadCredentialsStoreInKeychainEnabled)
        #endif
    }

    func testLastCommissionServerIdentifierRoundTrips() {
        let wrapper = MatterWrapper()
        XCTAssertNil(wrapper.lastCommissionServerIdentifier)

        wrapper.lastCommissionServerIdentifier = .init(rawValue: "server-1")
        XCTAssertEqual(wrapper.lastCommissionServerIdentifier?.rawValue, "server-1")
        XCTAssertEqual(MatterWrapper().lastCommissionServerIdentifier?.rawValue, "server-1")

        wrapper.lastCommissionServerIdentifier = nil
        XCTAssertNil(wrapper.lastCommissionServerIdentifier)
    }
}
#endif
