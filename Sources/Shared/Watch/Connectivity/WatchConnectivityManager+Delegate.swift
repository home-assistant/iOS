import Foundation
import WatchConnectivity

extension WatchConnectivityManager {
    // MARK: Internal receive entry points (testable without concrete WCSession types)

    func receiveMessage(_ content: [String: Any]) {
        guard let immediate = HAWatchConnectivity.ImmediateMessage(content: content) else { return }
        immediateMessage.notify(immediate)
    }

    func receiveMessage(_ content: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let interactive = HAWatchConnectivity.InteractiveImmediateMessage(
            content: content,
            wcReplyHandler: replyHandler
        ) else {
            // Reply anyway so the sender's reply handler doesn't hang until timeout.
            replyHandler([:])
            return
        }
        interactiveImmediateMessage.notify(interactive)
    }

    func receiveUserInfo(_ userInfo: [String: Any]) {
        if let complication = HAWatchConnectivity.ComplicationInfo(jsonDictionary: userInfo) {
            complicationInfo.notify(complication)
        } else if let guaranteed = HAWatchConnectivity.GuaranteedMessage(content: userInfo) {
            guaranteedMessage.notify(guaranteed)
        }
    }

    func receiveApplicationContext(_ applicationContext: [String: Any]) {
        context.notify(HAWatchConnectivity.Context(content: applicationContext))
    }

    func receiveBlob(fileURL: URL, metadata: [String: Any]?) {
        guard let decoded = HAWatchConnectivity.Blob.decode(fileURL: fileURL, metadata: metadata) else { return }
        blob.notify(decoded)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Current.Log.error("WatchConnectivity activation failed: \(error.localizedDescription)")
        }
        notifyState()
        notifyReachability()
        #if os(iOS)
        notifyWatchState()
        #endif
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        notifyReachability()
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        notifyState()
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        notifyState()
        // Re-activate so the app keeps talking to a newly-switched paired watch.
        session.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        notifyWatchState()
    }
    #endif

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receiveMessage(message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        receiveMessage(message, replyHandler: replyHandler)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receiveUserInfo(userInfo)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveApplicationContext(applicationContext)
    }

    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        receiveBlob(fileURL: file.fileURL, metadata: file.metadata)
    }

    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        resolveFileTransfer(fileTransfer, error: error)
    }

    public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        #if os(iOS)
        resolveComplicationTransfer(userInfoTransfer, error: error)
        #endif
    }
}
