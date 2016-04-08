//
//  DiscoverHA.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/7/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation

class BrowserDelegate : NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
    var resolving = [NSNetService]()
    
    func ipv4Enpoint(data: NSData) -> String {
        var address = sockaddr()
        data.getBytes(&address, length: sizeof(sockaddr))
        if address.sa_family == sa_family_t(AF_INET) {
            var addressIPv4 = sockaddr_in()
            data.getBytes(&addressIPv4, length: sizeof(sockaddr))
            let host = String.fromCString(inet_ntoa(addressIPv4.sin_addr))
            let port = Int(CFSwapInt16(addressIPv4.sin_port))
            return host!+":"+String(port)
        }
        return ""
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindDomain domainName: String, moreComing moreDomainsComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didFindDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveDomain domainName: String, moreComing moreDomainsComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didRemoveDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didFindService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didFindService")
        netService.delegate = self
        resolving.append(netService)
        netService.resolveWithTimeout(0.0)
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        print("Resolve address!")
//        for addressData in sender.addresses! {
//            print("Address data", addressData)
//        }
        for service in self.resolving {
            if service.port == -1 {
                print("service \(service.name) of type \(service.type)" +
                    " not yet resolved")
                service.delegate = self
                service.resolveWithTimeout(10)
            } else {
                print("service \(service.name) of type \(service.type)," +
                    "port \(service.port), addresses \(service.addresses)")
                let dataDict = NSNetService.dictionaryFromTXTRecordData(service.TXTRecordData()!)
                let baseUrl = copyStringFromTXTDict(dataDict, which: "base_url")
                let needsPassword = (copyStringFromTXTDict(dataDict, which: "needs_password") == "true")
                let version = copyStringFromTXTDict(dataDict, which: "version")
                print("Base URL", baseUrl!)
                print("Needs password", needsPassword)
                print("Version", version!)
                if let addresses = service.addresses {
                    for addressData in addresses {
                        let endpoint = ipv4Enpoint(addressData)
                        print("endpoint", endpoint)
                    }
                }
            }
        }
    }
    
    private func copyStringFromTXTDict(dict: [NSObject : AnyObject], which: String) -> String? {
        if let data = dict[which] as? NSData {
            return NSString(data: data, encoding: NSUTF8StringEncoding) as? String
        }
        else {
            return nil
        }
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didRemoveService netService: NSNetService, moreComing moreServicesComing: Bool) {
        NSLog("BrowserDelegate.netServiceBrowser.didRemoveService")
    }
    
    func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser){
        NSLog("BrowserDelegate.netServiceBrowserWillSearch")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser, didNotSearch errorInfo: [String : NSNumber]) {
        NSLog("BrowserDelegate.netServiceBrowser.didNotSearch")
    }
    
//    func netServiceBrowserDidStopSearch(netServiceBrowser: NSNetServiceBrowser) {
//        NSLog("BrowserDelegate.netServiceBrowserDidStopSearch")
//    }
    
}


class Discovery {
    let BM_DOMAIN = "local."
    let BM_TYPE = "_home-assistant._tcp."
    
    var nsb: NSNetServiceBrowser
    var nsbdel: BrowserDelegate?
    
    init() {
        self.nsb = NSNetServiceBrowser()
    }
    
    func start() {
        self.nsbdel = BrowserDelegate()
        nsb.delegate = nsbdel
        nsb.searchForServicesOfType(BM_TYPE, inDomain: BM_DOMAIN)
    }
    
    func stop() {
        nsb.stop()
    }
    
}