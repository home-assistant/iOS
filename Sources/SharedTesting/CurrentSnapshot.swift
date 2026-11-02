import Shared

/// The members of `Current` tests replace, captured so they can be put back.
///
/// `.sharedState` takes one before every test and restores it after, so a test that swaps
/// `Current.servers` or freezes `Current.date` and forgets to undo it cannot leave the change to
/// every test after it. Leftover fake servers are the expensive case: each sensor signal then sends
/// an update to every one of them, and each failed update keeps retrying for the rest of the run.
///
/// Lazily created members (`webhooks`, `kiosk`, `hinge`, `activeState` and the like) are left out,
/// since reading them here would create them.
public struct CurrentSnapshot {
    private let restorers: [() -> Void]

    /// Captures the members of `environment`, which defaults to whatever `Current` resolves to here.
    public init(of environment: AppEnvironment = Current) {
        func keep(_ keyPath: ReferenceWritableKeyPath<AppEnvironment, some Any>) -> () -> Void {
            let value = environment[keyPath: keyPath]
            return { environment[keyPath: keyPath] = value }
        }

        self.restorers = [
            keep(\.servers),
            keep(\.cachedApis),
            keep(\.sensors),
            keep(\.settingsStore),
            keep(\.modelManager),
            keep(\.date),
            keep(\.calendar),
            keep(\.database),
            keep(\.connectivity),
            keep(\.device),
            keep(\.location),
            keep(\.locationManager),
            keep(\.focusStatus),
            keep(\.focusFilter),
            keep(\.motion),
            keep(\.pedometer),
            keep(\.barometer),
            keep(\.barometerObserver),
            keep(\.healthKitService),
            keep(\.matter),
            keep(\.isAppExtension),
            keep(\.isTestFlight),
            keep(\.isCatalyst),
            keep(\.backgroundTask),
            keep(\.bonjour),
            keep(\.websiteDataStoreHandler),
            keep(\.magicItemProvider),
            keep(\.appEntitiesModel),
            keep(\.areasProvider),
            keep(\.frontendTheme),
            keep(\.calendarsModel),
            keep(\.appDatabaseUpdater),
            keep(\.panelsUpdater),
            keep(\.notificationDispatcher),
            keep(\.clientEventStore),
            keep(\.customWidgets),
            keep(\.watchConfig),
            keep(\.carPlayConfig),
            keep(\.requestSensorPermissions),
            keep(\.screenBrightness),
            keep(\.setScreenBrightness),
            keep(\.application),
            keep(\.isPerformingSingleShotLocationQuery),
        ] + Self.sessionValues(of: environment)
    }

    /// The session values object is shared by every environment, so putting the member back is not
    /// enough: a handled invitation link leaves its URL on it, and the onboarding screens shown by
    /// later tests would open on that invitation.
    private static func sessionValues(of environment: AppEnvironment) -> [() -> Void] {
        let inviteURL = environment.appSessionValues.inviteURL
        return [{ environment.appSessionValues.inviteURL = inviteURL }]
    }

    /// Puts every captured member back.
    public func restore() {
        for restore in restorers {
            restore()
        }
    }
}
