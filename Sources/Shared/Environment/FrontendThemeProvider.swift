import Foundation
import HADesignSystem
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Caches the captured frontend theme in memory and resolves it into colours native screens can use.
///
/// The database is the record — it survives launches and is what makes a native screen themed before
/// the web view has even loaded — but a screen asks for one property at a time while it lays out, so
/// the whole set is read once and kept here. Nothing in this type talks to the web view; capturing is
/// the web view's job, and it arrives through ``store(_:for:appearance:)``.
public final class FrontendThemeProvider: FrontendThemeProviderProtocol {
    public static var shared: FrontendThemeProviderProtocol = FrontendThemeProvider()

    /// Posted after a capture replaces a stored theme. Screens that cached a resolved colour observe
    /// this to recompute it; the values themselves are read back through the provider.
    public static let didChangeNotification = Notification.Name("FrontendThemeProviderDidChange")

    /// Guards `cache` and `hasLoaded`, which are read from whatever thread is laying out a screen and
    /// written from the main-actor web view callback.
    private let lock = NSLock()
    /// ["\(serverId)|\(appearance)": [propertyName: variable]]
    private var cache: [String: [String: FrontendThemeVariable]] = [:]
    private var hasLoaded = false

    init() {}

    public func variables(
        for serverId: String?,
        appearance: FrontendThemeAppearance
    ) -> [String: FrontendThemeVariable] {
        guard let serverId = resolvedServerId(serverId) else { return [:] }
        loadIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return cache[Self.cacheKey(serverId: serverId, appearance: appearance)] ?? [:]
    }

    public func value(of name: String, for serverId: String?, appearance: FrontendThemeAppearance) -> String? {
        variables(for: serverId, appearance: appearance)[name]?.value
    }

    public func color(of name: String, for serverId: String?) -> Color? {
        let light = storedColor(name: name, serverId: serverId, appearance: .light)
        let dark = storedColor(name: name, serverId: serverId, appearance: .dark)
        guard light != nil || dark != nil else { return nil }
        return Self.adaptiveColor(light: light, dark: dark)
    }

    public func color(_ frontendColor: FrontendColors, for serverId: String?) -> Color {
        // Each appearance falls back on its own: a user who has only ever opened the app in light mode
        // has no dark rows, and the frontend's own dark default is a better answer there than the
        // light colour they happen to have captured.
        let light = storedColor(name: frontendColor.rawValue, serverId: serverId, appearance: .light)
            ?? frontendColor.lightColor
        let dark = storedColor(name: frontendColor.rawValue, serverId: serverId, appearance: .dark)
            ?? frontendColor.darkColor
        return Self.adaptiveColor(light: light, dark: dark)
    }

    public func store(_ variables: [FrontendThemeVariable], for serverId: String, appearance: FrontendThemeAppearance) {
        do {
            try FrontendThemeVariable.replaceAll(variables, serverId: serverId, appearance: appearance)
        } catch {
            Current.Log.error("Failed to persist frontend theme variables, error: \(error)")
            return
        }
        lock.lock()
        // `hasLoaded` is deliberately left alone: this filled one server/appearance, and claiming the
        // whole cache is loaded would hide every other server's persisted rows until the next reload.
        // The merge in `loadIfNeeded` keeps what was just stored, so the load stays safe to run after.
        cache[Self.cacheKey(serverId: serverId, appearance: appearance)] = Dictionary(
            variables.map { ($0.name, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    public func reload() {
        lock.lock()
        hasLoaded = false
        cache = [:]
        lock.unlock()
        loadIfNeeded()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func storedColor(name: String, serverId: String?, appearance: FrontendThemeAppearance) -> Color? {
        guard let variable = variables(for: serverId, appearance: appearance)[name] else { return nil }
        // `colorValue` is the browser's canonical form and is only set when the property parsed as a
        // colour; `value` is tried as well so a theme captured before that distinction existed, or one
        // whose raw value is already a colour literal, still resolves.
        guard let raw = variable.colorValue ?? variable.value.nilIfEmpty else { return nil }
        return UIColor(cssColorString: raw).map { Color($0) }
    }

    private func loadIfNeeded() {
        lock.lock()
        let needsLoad = !hasLoaded
        lock.unlock()
        guard needsLoad else { return }

        var loaded: [String: [String: FrontendThemeVariable]] = [:]
        do {
            for variable in try FrontendThemeVariable.fetchAllVariables() {
                let key = Self.cacheKey(serverId: variable.serverId, appearance: variable.appearance)
                loaded[key, default: [:]][variable.name] = variable
            }
        } catch {
            Current.Log.error("Failed to load frontend theme variables, error: \(error)")
            return
        }

        lock.lock()
        // A capture that landed while the read was in flight is newer than what came back from it, so
        // it wins: only the server/appearance sets it did not touch are filled in.
        cache = loaded.merging(cache, uniquingKeysWith: { _, stored in stored })
        hasLoaded = true
        lock.unlock()
    }

    /// The server a screen means when it doesn't name one: the one the user was last looking at.
    private func resolvedServerId(_ serverId: String?) -> String? {
        if let serverId {
            return serverId
        }
        let lastActive = Current.settingsStore.lastActiveServerIdentifier
        return Current.servers.server(forServerIdentifier: lastActive)?.identifier.rawValue
            ?? Current.servers.all.first?.identifier.rawValue
    }

    private static func cacheKey(serverId: String, appearance: FrontendThemeAppearance) -> String {
        "\(serverId)|\(appearance.rawValue)"
    }

    private static func adaptiveColor(light: Color?, dark: Color?) -> Color {
        #if os(watchOS)
        return dark ?? light ?? .clear
        #else
        let lightColor = light ?? dark ?? .clear
        let darkColor = dark ?? light ?? .clear
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
        })
        #endif
    }
}
