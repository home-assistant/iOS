import Foundation
import Sentry

public protocol CrashReporter {
    func setUserProperty(value: String?, name: String)
    func logEvent(event: String, params: [String: Any])
    func logError(_ error: NSError)
}

public class CrashReporterImpl: CrashReporter {
    internal func setup(environment: Environment) {
        guard environment.settingsStore.privacy.crashes else {
            return
        }

        guard Constants.BundleID.starts(with: "io.robbie.") else {
            return
        }

        environment.Log.add(destination: SentryLogDestination())

        SentrySDK.start { options in
            options.dsn = "https://762c198b86594fa2b6bedf87028db34d@o427061.ingest.sentry.io/5372775"
            options.debug = environment.appConfiguration == .Debug
            options.enableAutoSessionTracking = environment.settingsStore.privacy.analytics
            options.maxBreadcrumbs = 1000

            var integrations = type(of: options).defaultIntegrations()

            let analyticsIntegrations = Set([
                "SentryAutoBreadcrumbTrackingIntegration",
                "SentryAutoSessionTrackingIntegration"
            ])

            let crashesIntegrations = Set([
                "SentryCrashIntegration"
            ])

            if !environment.settingsStore.privacy.crashes {
                integrations.removeAll(where: { crashesIntegrations.contains($0) })
            }

            if !environment.settingsStore.privacy.analytics {
                integrations.removeAll(where: { analyticsIntegrations.contains($0) })
            }

            options.integrations = integrations
        }
    }

    public func setUserProperty(value: String?, name: String) {
        SentrySDK.configureScope { scope in
            scope.setEnvironment(Current.appConfiguration.description)

            if let value = value {
                Current.Log.verbose("setting tag \(name) to '\(value)'")
                scope.setTag(value: value, key: name)
            } else {
                Current.Log.verbose("removing tag \(name)")
                scope.removeTag(key: name)
            }
        }
    }

    public func logEvent(event: String, params: [String: Any]) {
        guard Current.settingsStore.privacy.analytics else { return}

        Current.Log.verbose("event \(event): \(params)")
        SentrySDK.capture(message: event) { scope in
            scope.setTags(params.mapValues { String(describing: $0)})
        }
    }

    public func logError(_ error: NSError) {
        // crash reporting is controlled by the crashes key, but this is more like analytics
        guard Current.settingsStore.privacy.analytics else { return}

        Current.Log.error("error: \(error.debugDescription)")
        SentrySDK.capture(error: error)
    }
}
