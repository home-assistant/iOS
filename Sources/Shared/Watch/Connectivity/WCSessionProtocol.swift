import Foundation
import WatchConnectivity

/// Identity handle for an in-flight transfer, so completions can be keyed by `ObjectIdentifier`
/// without depending on the (non-constructible) concrete WatchConnectivity transfer classes.
public protocol WCTransferHandle: AnyObject {}

extension WCSessionUserInfoTransfer: WCTransferHandle {}
extension WCSessionFileTransfer: WCTransferHandle {}

/// The subset of `WCSession` the connectivity layer touches, abstracted for testability. `…Proxy`
/// suffixes avoid redeclaring `WCSession`'s own members in its conformance.
public protocol WCSessionProtocol: AnyObject {
    var delegateProxy: WCSessionDelegate? { get set }
    var activationStateProxy: WCSessionActivationState { get }
    var isReachableProxy: Bool { get }
    var hasContentPendingProxy: Bool { get }
    var applicationContextProxy: [String: Any] { get }
    var receivedApplicationContextProxy: [String: Any] { get }
    /// Payloads of `transferUserInfo` calls not yet delivered to the counterpart.
    var outstandingUserInfoTransfersProxy: [[String: Any]] { get }

    func activateProxy()
    func sendMessageProxy(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )
    func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws
    @discardableResult func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle
    @discardableResult func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle

    #if os(iOS)
    var isPairedProxy: Bool { get }
    var isWatchAppInstalledProxy: Bool { get }
    var isComplicationEnabledProxy: Bool { get }
    var remainingComplicationUserInfoTransfersProxy: Int { get }
    var watchDirectoryURLProxy: URL? { get }
    @discardableResult func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle
    #endif
}

extension WCSession: WCSessionProtocol {
    public var delegateProxy: WCSessionDelegate? {
        get { delegate }
        set { delegate = newValue }
    }

    public var activationStateProxy: WCSessionActivationState { activationState }
    public var isReachableProxy: Bool { isReachable }
    public var hasContentPendingProxy: Bool { hasContentPending }
    public var applicationContextProxy: [String: Any] { applicationContext }
    public var receivedApplicationContextProxy: [String: Any] { receivedApplicationContext }
    public var outstandingUserInfoTransfersProxy: [[String: Any]] {
        outstandingUserInfoTransfers.map(\.userInfo)
    }

    public func activateProxy() { activate() }

    public func sendMessageProxy(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    public func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws {
        try updateApplicationContext(applicationContext)
    }

    @discardableResult public func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        transferUserInfo(userInfo)
    }

    @discardableResult public func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle {
        transferFile(file, metadata: metadata)
    }

    #if os(iOS)
    public var isPairedProxy: Bool { isPaired }
    public var isWatchAppInstalledProxy: Bool { isWatchAppInstalled }
    public var isComplicationEnabledProxy: Bool { isComplicationEnabled }
    public var remainingComplicationUserInfoTransfersProxy: Int { remainingComplicationUserInfoTransfers }
    public var watchDirectoryURLProxy: URL? { watchDirectoryURL }

    @discardableResult public func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any])
        -> WCTransferHandle {
        transferCurrentComplicationUserInfo(userInfo)
    }
    #endif
}
