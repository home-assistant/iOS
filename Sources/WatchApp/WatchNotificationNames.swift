import Foundation

extension Notification.Name {
    /// Posted on the watch once client certificate(s) received from the paired iPhone have been
    /// imported into the local Keychain, so any visible mTLS status can refresh.
    static let clientCertificatesImported = Notification.Name("clientCertificatesImported")
    /// Posted on the watch when the watch configuration changes (e.g. after saving Assist settings) so
    /// open screens can reload their cached copy.
    static let watchConfigDidChange = Notification.Name("watchConfigDidChange")
}
