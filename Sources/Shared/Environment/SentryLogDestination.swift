import Foundation
import XCGLogger
import Sentry

open class SentryLogDestination: BaseQueuedDestination {
    open override func output(logDetails: LogDetails, message: String) {
        guard Current.settingsStore.privacy.analytics else {
            return
        }

        let breadcrumb = Breadcrumb(level: .init(xcgLogLevel: logDetails.level), category: "log")
        breadcrumb.message = message
        SentrySDK.addBreadcrumb(crumb: breadcrumb)
    }
}

private extension SentryLevel {
    init(xcgLogLevel: XCGLogger.Level) {
        self = {
            switch xcgLogLevel {
            case .verbose: return .debug
            case .debug: return .debug
            case .info: return .info
            case .notice: return .warning
            case .warning: return .warning
            case .error: return .error
            case .severe: return .fatal
            case .alert: return .fatal
            case .emergency: return .fatal
            case .none: return .none
            }
        }()
    }
}
