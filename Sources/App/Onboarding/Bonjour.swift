import Foundation
import Shared

public protocol BonjourObserver: AnyObject {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant)
    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String)
}

public class Bonjour: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    public weak var observer: BonjourObserver?

    private var browser: NetServiceBrowser
    private var resolving = [NetService]()
    private var resolvingDict = [String: NetService]()
    private var browserIsRunning: Bool = false

    override public init() {
        self.browser = NetServiceBrowser()
        super.init()
    }

    public func start() {
        precondition(Thread.isMainThread)
        guard !browserIsRunning else { return }
        Current.Log.info("starting")
        browserIsRunning = true
        browser.delegate = self
        browser.searchForServices(ofType: "_home-assistant._tcp.", inDomain: "local.")
    }

    public func stop() {
        precondition(Thread.isMainThread)
        guard browserIsRunning else { return }
        Current.Log.info("stopping")
        browserIsRunning = false
        browser.stop()
        browser.delegate = nil
    }

    // Browser methods

    public func netServiceBrowser(
        _ netServiceBrowser: NetServiceBrowser,
        didFind netService: NetService,
        moreComing moreServicesComing: Bool
    ) {
        Current.Log.verbose("BonjourDelegate.Browser.didFindService")
        netService.delegate = self
        resolvingDict[netService.name] = netService
        netService.resolve(withTimeout: 0.0)
    }

    public func netServiceDidResolveAddress(_ sender: NetService) {
        Current.Log.verbose("BonjourDelegate.Browser.netServiceDidResolveAddress")
        if let txtRecord = sender.txtRecordData() {
            let potentialServiceDict = NetService.dictionary(fromTXTRecord: txtRecord) as NSDictionary

            // This fixes a crash in 0.110, the root cause is the dictionary returned
            // above contains NSNull instead of NSData, which Swift will crash trying
            // to cast to the Swift dictionary. So we do it the hard way.
            let serviceDict = (potentialServiceDict as? [String: Any])?
                .compactMapValues { $0 as? Data } ?? [:]

            let discoveryInfo = discoveryInfoFromDict(locationName: sender.name, netServiceDictionary: serviceDict)
            observer?.bonjour(self, didAdd: discoveryInfo)
        }
    }

    public func netServiceBrowser(
        _ netServiceBrowser: NetServiceBrowser,
        didRemove netService: NetService,
        moreComing moreServicesComing: Bool
    ) {
        Current.Log.verbose("BonjourDelegate.Browser.didRemoveService")

        observer?.bonjour(self, didRemoveInstanceWithName: netService.name)
        resolvingDict.removeValue(forKey: netService.name)
    }

    private func discoveryInfoFromDict(
        locationName: String,
        netServiceDictionary: [String: Data]
    ) -> DiscoveredHomeAssistant {
        var outputDict: [String: Any] = [:]
        for (key, value) in netServiceDictionary {
            outputDict[key] = String(data: value, encoding: .utf8)
            if outputDict[key] as? String == "true" || outputDict[key] as? String == "false" {
                if let stringedKey = outputDict[key] as? String {
                    outputDict[key] = Bool(stringedKey)
                }
            }
        }
        outputDict["location_name"] = locationName
        return DiscoveredHomeAssistant(JSON: outputDict)!
    }
}
