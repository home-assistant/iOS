//
//  SecondViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import PermissionScope
import AcknowList
import PromiseKit
import Crashlytics
import SafariServices
import Alamofire
import AlamofireObjectMapper

class SettingsViewController: FormViewController {

    let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!
    
    var showErrorConnectingMessage = false
    
    var baseURL : URL? = nil
    var password : String? = nil
    var configured: Bool = false
    var connectStep : Int = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let baseURL = prefs.string(forKey: "baseURL") {
            self.baseURL = URL(string: baseURL)!
        }
        
        if let apiPass = prefs.string(forKey: "apiPassword") {
            self.password = apiPass
        }
        
        self.configured = (self.baseURL != nil && self.password != nil)
        
        checkForEmail()
        
        if showErrorConnectingMessage {
            let alert = UIAlertController(title: "Connection error", message: "There was an error connecting to Home Assistant. Please confirm the settings are correct and save to attempt to reconnect.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
        if self.configured == false {
            let discovery = Bonjour()
            
            let queue = DispatchQueue(label: "io.robbie.homeassistant", attributes: []);
            queue.async { () -> Void in
                NSLog("Attempting to discover Home Assistant instances, also publishing app to Bonjour/mDNS to hopefully have HA load the iOS/ZeroConf components.")
                discovery.stopDiscovery()
                discovery.stopPublish()
                
                discovery.startDiscovery()
                discovery.startPublish()
                
                sleep(60)
                
                NSLog("Stopping Home Assistant discovery")
                discovery.stopDiscovery()
                discovery.stopPublish()
            }
            
            NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.HomeAssistantDiscovered(_:)), name:NSNotification.Name(rawValue: "homeassistant.discovered"), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.HomeAssistantUndiscovered(_:)), name:NSNotification.Name(rawValue: "homeassistant.undiscovered"), object: nil)
        }
        
        form
            +++ Section(header: "Discovered Home Assistants", footer: ""){
                $0.tag = "discoveredInstances"
                $0.hidden = true
            }

            +++ Section(header: "Connection", footer: "")
            <<< URLRow("baseURL") {
                $0.title = "URL"
                $0.value = self.baseURL
                $0.placeholder = "https://homeassistant.myhouse.com"
                $0.disabled = Condition(booleanLiteral: self.configured)
            }.onChange { row in
                if row.value == URL(string: "https://") { return }
                let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
                apiPasswordRow.value = ""
                if let url = row.value {
                    let cleanUrl = HomeAssistantAPI.sharedInstance.CleanBaseURL(baseUrl: url)
                    if !cleanUrl.hasValidScheme {
                        let alert = UIAlertController(title: "Invalid URL", message: "The URL must begin with either http:// or https://.", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        self.baseURL = cleanUrl.cleanedURL
                    }
                }
            }.cellUpdate { cell, row in
                if row.isHighlighted {
                    row.value = URL(string: "https://")
                } else {
                    if row.value == URL(string: "https://") {
                        row.value = nil
                        cell.update()
                    }
                }
            }
            
            <<< PasswordRow("apiPassword") {
                $0.title = "Password"
                $0.value = self.password
                $0.disabled = Condition(booleanLiteral: self.configured)
                $0.placeholder = "password"
            }.onChange { row in
                self.password = row.value
            }
            
            <<< ButtonRow("connect") {
                $0.title = "Connect"
                $0.hidden = Condition(booleanLiteral: self.configured)
            }.onCellSelection { _, row in
                if self.connectStep == 1 {
                    if let url = self.baseURL {
                        HomeAssistantAPI.sharedInstance.GetDiscoveryInfo(baseUrl: url).then { discoveryInfo -> Void in
                            let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
                            urlRow.disabled = true
                            urlRow.evaluateDisabled()
                            let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
                            apiPasswordRow.value = ""
                            apiPasswordRow.hidden = Condition(booleanLiteral: !discoveryInfo.RequiresPassword)
                            apiPasswordRow.evaluateHidden()
                            self.connectStep = 2
                        }.catch { error in
                            print("Hit error when attempting to get discovery information", error)
                            let alert = UIAlertController(title: "Error during connection attempt", message: "\(error.localizedDescription)\r\n\r\nPlease try again.", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                } else if self.connectStep == 2 {
                    firstly {
                        HomeAssistantAPI.sharedInstance.Setup(baseAPIUrl: self.baseURL!.absoluteString, APIPassword: self.password!)
                    }.then {_ in
                        HomeAssistantAPI.sharedInstance.Connect()
                    }.then { config -> Void in
                        print("Connected!")
                        self.connectStep = 1
                        row.hidden = true
                        row.evaluateHidden()
                        if let url = self.baseURL {
                            self.prefs.setValue(url.absoluteString, forKey: "baseURL")
                        }
                        if let password = self.password {
                            self.prefs.setValue(password, forKey: "apiPassword")
                        }
                        self.prefs.synchronize()
                        self.dismiss(animated: true, completion: nil)
                    }.catch { error in
                        print("Connection error!", error)
                        var errorMessage = error.localizedDescription
                        if let error = error as? AFError {
                            if error.responseCode == 401 {
                                errorMessage = "The password was incorrect."
                            }
                        }
                        let alert = UIAlertController(title: "Error during connection with authentication attempt", message: "\(errorMessage)\r\n\r\nPlease try again.", preferredStyle: UIAlertControllerStyle.alert)
                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }

            +++ Section(header: "", footer: "Device ID is the identifier used when sending location updates to Home Assistant, as well as the target to send push notifications to.")
            <<< TextRow("deviceId") {
                $0.title = "Device ID"
                if let deviceId = prefs.string(forKey: "deviceId") {
                    $0.value = deviceId
                } else {
                    $0.value = removeSpecialCharsFromString(text: UIDevice.current.name).replacingOccurrences(of: " ", with: "_").lowercased()
                }
                $0.cell.textField.autocapitalizationType = .none
            }.cellUpdate { cell, row in
                if row.isHighlighted == false {
                    self.prefs.setValue(row.value, forKey: "deviceId")
                    self.prefs.synchronize()
                }
            }
//            <<< SwitchRow("allowAllGroups") {
//                $0.title = "Show all groups"
//                $0.value = prefs.bool(forKey: "allowAllGroups")
//            }
            +++ Section()
            <<< ButtonRow("displaySettings") {
                $0.title = "Display Settings"
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "display"
                    return view
                }, onDismiss: { vc in
                    let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
            
            <<< ButtonRow("enableLocation"){
                $0.title = "Enable location tracking"
                $0.hidden = Condition(booleanLiteral: PermissionScope().statusLocationAlways() == .unknown)
                $0.evaluateHidden()
            }.onCellSelection { cell, row in
                print("locationEnabled?", HomeAssistantAPI.sharedInstance.locationEnabled)
                print("locationEnabled?", (HomeAssistantAPI.sharedInstance.locationEnabled == false))
                let pscope = PermissionScope()
                
                pscope.addPermission(LocationAlwaysPermission(),
                                     message: "We use this to inform\r\nHome Assistant of your device location and state.")
                pscope.show({finished, results in
                    if finished {
                        print("Location Permissions finished!", finished, results)
                        if results[0].status == .authorized {
                            HomeAssistantAPI.sharedInstance.trackLocation()
                        }
                        row.hidden = true
                        row.evaluateHidden()
                        let locationSettingsRow: ButtonRow = self.form.rowBy(tag: "locationSettings")!
                        locationSettingsRow.hidden = false
                        locationSettingsRow.evaluateHidden()
                    }
                }, cancelled: { (results) -> Void in
                    print("Permissions finished, resetting API!")
                })
            }
            
            <<< ButtonRow("locationSettings") {
                $0.title = "Location Settings"
                $0.hidden = Condition(booleanLiteral: PermissionScope().statusLocationAlways() == .authorized)
                $0.evaluateHidden()
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    let view = SettingsDetailViewController()
                    view.detailGroup = "location"
                    return view
                }, onDismiss: { vc in
                    let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
            
            <<< ButtonRow("enableNotifications"){
                $0.title = "Enable notifications"
                $0.hidden = Condition(booleanLiteral: HomeAssistantAPI.sharedInstance.notificationsEnabled)
            }.onCellSelection { cell, row in
                let pscope = PermissionScope()
                
                pscope.addPermission(NotificationsPermission(),
                                     message: "We use this to let you\r\nsend notifications to your device.")
                pscope.show({finished, results in
                    if finished {
                        print("Notifications Permissions finished!", finished, results)
                        if results[0].status == .authorized {
                            HomeAssistantAPI.sharedInstance.setupPush()
                        }
                        row.hidden = true
                        row.evaluateHidden()
                        let notificationSettingsRow: ButtonRow = self.form.rowBy(tag: "notificationSettings")!
                        notificationSettingsRow.hidden = false
                        notificationSettingsRow.evaluateHidden()
                    }
                }, cancelled: { (results) -> Void in
                    print("Permissions finished, resetting API!")
                })
            }
            
            <<< ButtonRow("notificationSettings") {
                $0.title = "Notification Settings"
                $0.hidden = Condition(booleanLiteral: !HomeAssistantAPI.sharedInstance.notificationsEnabled)
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    print("HomeAssistantAPI.sharedInstance.notificationsEnabled", HomeAssistantAPI.sharedInstance.notificationsEnabled)
                    let view = SettingsDetailViewController()
                    view.detailGroup = "notifications"
                    return view
                }, onDismiss: { vc in
                    let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
        
            +++ Section()
            <<< ButtonRow("resetApp") {
                $0.title = "Reset"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection{ cell, row in
                let alert = UIAlertController(title: "Reset", message: "Your settings will be reset, this device unregistered from push notifications, and removed from your Home Assistant configuration.", preferredStyle: UIAlertControllerStyle.alert)
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
                    print("Handle Cancel Logic here")
                }))
                
                alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { (action: UIAlertAction!) in
                    print("Handle Ok logic here")
                }))
                
                self.present(alert, animated: true, completion: nil)
            }
            
            +++ Section()
            <<< ButtonRow("helpButton") {
                $0.title = "Help"
                $0.presentationMode = .presentModally(controllerProvider: ControllerProvider.callback {
                    return SFSafariViewController(url: URL(string: "https://community.home-assistant.io/c/ios")!, entersReaderIfAvailable: false)
                }, onDismiss: { vc in
                    let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
            <<< ButtonRow("acknowledgementsButton") {
                $0.title = "Acknowledgements"
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return AcknowListViewController()
                }, onDismiss: { vc in
                    let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
        
//        if showErrorConnectingMessage == false {
//            if let endpointArn = prefs.string(forKey: "endpointARN") {
//                form
//                    +++ Section(header: "Push Notifications", footer: "")
//                    <<< TextAreaRow() {
//                        $0.placeholder = "EndpointArn"
//                        $0.value = endpointArn.components(separatedBy: "/").last
//                        $0.disabled = true
//                        $0.textAreaHeight = TextAreaHeight.dynamic(initialTextViewHeight: 40)
//                    }
//                    
//                    <<< ButtonRow() {
//                        $0.title = "Update push settings"
//                    }.onCellSelection {_,_ in
//                        HomeAssistantAPI.sharedInstance.setupPush()
//                        let alert = UIAlertController(title: "Settings Import", message: "Push settings imported from Home Assistant.", preferredStyle: UIAlertControllerStyle.alert)
//                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
//                        self.present(alert, animated: true, completion: nil)
//                    }
//                    
//                    <<< ButtonRow() {
//                        $0.title = "Import sounds from iTunes"
//                    }.onCellSelection {_,_ in
//                        let moved = movePushNotificationSounds()
//                        let message = (moved > 0) ? "\(moved) sounds were imported. Please restart your phone to complete the import." : "0 sounds were imported."
//                        let alert = UIAlertController(title: "Sounds Import", message: message, preferredStyle: UIAlertControllerStyle.alert)
//                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
//                        self.present(alert, animated: true, completion: nil)
//                    }
//
////                    <<< ButtonRow() {
////                        $0.title = "Import system sounds"
////                    }.onCellSelection {_,_ in
////                        let list = getSoundList()
////                        print("system sounds list", list)
////                        for sound in list {
////                            copyFileToDirectory(sound)
////                        }
////
////                    }
//            }
//            
//            for zone in realm.objects(Zone.self) {
//                form
//                    +++ Section(header: zone.Name, footer: "") {
//                        $0.tag = zone.ID
//                    }
//                    <<< SwitchRow() {
//                        $0.title = "Updates Enabled"
//                        $0.value = zone.trackingEnabled
//                    }.onChange { row in
//                        try! realm.write { zone.trackingEnabled = row.value! }
//                    }
//                    <<< LocationRow() {
//                        $0.title = "Location"
//                        $0.value = zone.location()
//                    }
//                    <<< LabelRow(){
//                        $0.title = "Radius"
//                        $0.value = "\(Int(zone.Radius)) m"
//                    }
//                    <<< SwitchRow() {
//                        $0.title = "Enter Notification"
//                        $0.value = zone.enterNotification
//                        }.onChange { row in
//                            try! realm.write { zone.enterNotification = row.value! }
//                    }
//                    <<< SwitchRow() {
//                        $0.title = "Exit Notification"
//                        $0.value = zone.exitNotification
//                        }.onChange { row in
//                            try! realm.write { zone.exitNotification = row.value! }
//                }
//            }
//        }
//        
//
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func HomeAssistantDiscovered(_ notification: Notification){
        let discoverySection : Section = self.form.sectionBy(tag: "discoveredInstances")!
        discoverySection.hidden = false
        discoverySection.evaluateHidden()
        if let userInfo = (notification as Notification).userInfo as? [String:Any] {
            let discoveryInfo = DiscoveryInfoResponse(JSON: userInfo)!
            let needsPass = discoveryInfo.RequiresPassword ? " - Requires password" : ""
            let detailTextLabel = "\(discoveryInfo.BaseURL!.host!):\(discoveryInfo.BaseURL!.port!) - \(discoveryInfo.Version) - \(discoveryInfo.BaseURL!.scheme!.uppercased()) \(needsPass)"
            if self.form.rowBy(tag: discoveryInfo.LocationName) == nil {
                discoverySection
                    <<< ButtonRow(discoveryInfo.LocationName) {
                            $0.title = discoveryInfo.LocationName
                            $0.cellStyle = UITableViewCellStyle.subtitle
                        }.cellUpdate { cell, row in
                            cell.textLabel?.textColor = .black
                            cell.detailTextLabel?.text = detailTextLabel
                        }.onCellSelection({ cell, row in
                            let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
                            urlRow.value = discoveryInfo.BaseURL
                            urlRow.disabled = true
                            urlRow.evaluateDisabled()
                            let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword")!
                            apiPasswordRow.value = ""
                            apiPasswordRow.hidden = Condition(booleanLiteral: !discoveryInfo.RequiresPassword)
                            apiPasswordRow.evaluateHidden()
                            self.connectStep = 2
                        })
                self.tableView?.reloadData()
            } else {
                if let readdedRow : ButtonRow = self.form.rowBy(tag: discoveryInfo.LocationName) {
                    readdedRow.hidden = false
                    readdedRow.updateCell()
                    readdedRow.evaluateHidden()
                }
            }
        }
    }

    func HomeAssistantUndiscovered(_ notification: Notification){
        if let userInfo = (notification as Notification).userInfo {
            let name = userInfo["name"] as! String
            if let removingRow : ButtonRow = self.form.rowBy(tag: name) {
                removingRow.hidden = true
                removingRow.evaluateHidden()
                removingRow.updateCell()
            }
        }
        let discoverySection : Section = self.form.sectionBy(tag: "discoveredInstances")!
        discoverySection.hidden = Condition(booleanLiteral: (discoverySection.count < 1))
        discoverySection.evaluateHidden()
    }

    
    @IBOutlet var emailInput: UITextField!
    func emailEntered(_ sender: UIAlertAction) {
        if let email = emailInput.text {
            if emailInput.text != "" {
                print("Captured email", email)
                Crashlytics.sharedInstance().setUserEmail(email)
                print("First launch, setting NSUserDefault.")
                prefs.set(true, forKey: "emailSet")
                prefs.set(email, forKey: "userEmail")
            } else {
                checkForEmail()
            }
        } else {
            checkForEmail()
        }
    }
    
    func checkForEmail() {
        if prefs.bool(forKey: "emailSet") == false || prefs.string(forKey: "userEmail") == nil {
            print("This is first launch, let's prompt user for email.")
            let alert = UIAlertController(title: "Welcome", message: "Please enter the email address you used to sign up for the beta program with.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: emailEntered))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "myawesomeemail@gmail.com"
                textField.keyboardType = .emailAddress
                self.emailInput = textField
            })
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func saveSettings() {
        if let urlRow: URLRow = self.form.rowBy(tag: "baseURL") {
            if let url = urlRow.value {
                self.prefs.setValue(url.absoluteString, forKey: "baseURL")
            }
        }
        if let apiPasswordRow: PasswordRow = self.form.rowBy(tag: "apiPassword") {
            if let password = apiPasswordRow.value {
                self.prefs.setValue(password, forKey: "apiPassword")
            }
        }
        if let deviceIdRow: TextRow = self.form.rowBy(tag: "deviceId") {
            if let deviceId = deviceIdRow.value {
                self.prefs.setValue(deviceId, forKey: "deviceId")
            }
        }
        if let allowAllGroupsRow: SwitchRow = self.form.rowBy(tag: "allowAllGroups") {
            if let allowAllGroups = allowAllGroupsRow.value {
                self.prefs.set(allowAllGroups, forKey: "allowAllGroups")
            }
        }
        
        self.prefs.synchronize()
        
        let pscope = PermissionScope()
        
        pscope.addPermission(LocationAlwaysPermission(),
                             message: "We use this to inform\r\nHome Assistant of your device presence.")
        pscope.addPermission(NotificationsPermission(),
                             message: "We use this to let you\r\nsend notifications to your device.")
        pscope.show({finished, results in
            if finished {
                print("Permissions finished, resetting API!", results)
                self.dismiss(animated: true, completion: nil)
                (UIApplication.shared.delegate as! AppDelegate).initAPI()
            }
        }, cancelled: { (results) -> Void in
            print("Permissions finished, resetting API!")
            self.dismiss(animated: true, completion: nil)
            (UIApplication.shared.delegate as! AppDelegate).initAPI()
        })
    }
}

func removeSpecialCharsFromString(text: String) -> String {
    let okayChars : Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890".characters)
    return String(text.characters.filter {okayChars.contains($0) })
}
