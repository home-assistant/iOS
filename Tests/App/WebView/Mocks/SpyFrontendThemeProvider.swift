import Foundation
import Shared
import SwiftUI
import XCTest

/// Records what the web view asked to persist, so the message handler can be tested without a database.
/// The store lands on a background queue, hence the lock and the expectation.
final class SpyFrontendThemeProvider: FrontendThemeProviderProtocol {
    private let lock = NSLock()
    private var captured: (variables: [FrontendThemeVariable], serverId: String, appearance: FrontendThemeAppearance)?
    var storeExpectation: XCTestExpectation?

    var storeCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return captured != nil
    }

    var storedVariables: [FrontendThemeVariable] {
        lock.lock()
        defer { lock.unlock() }
        return captured?.variables ?? []
    }

    var storedServerId: String? {
        lock.lock()
        defer { lock.unlock() }
        return captured?.serverId
    }

    var storedAppearance: FrontendThemeAppearance? {
        lock.lock()
        defer { lock.unlock() }
        return captured?.appearance
    }

    func variables(for serverId: String?, appearance: FrontendThemeAppearance) -> [String: FrontendThemeVariable] {
        [:]
    }

    func value(of name: String, for serverId: String?, appearance: FrontendThemeAppearance) -> String? {
        nil
    }

    func color(of name: String, for serverId: String?) -> Color? {
        nil
    }

    func color(_ frontendColor: FrontendColors, for serverId: String?) -> Color {
        .clear
    }

    func store(_ variables: [FrontendThemeVariable], for serverId: String, appearance: FrontendThemeAppearance) {
        lock.lock()
        captured = (variables, serverId, appearance)
        lock.unlock()
        storeExpectation?.fulfill()
    }

    func reload() {}
}
