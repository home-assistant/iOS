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

class SettingsViewController: FormViewController {

    let prefs = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let aboutButton = UIBarButtonItem(title: "About", style: .Plain, target: self, action: #selector(SettingsViewController.aboutButtonPressed(_:)))
        
        self.navigationItem.rightBarButtonItem = aboutButton
        
        let discovery = Discovery()
        
        let queue = dispatch_queue_create("io.robbie.homeassistant", nil);
        dispatch_async(queue) { () -> Void in
            NSLog("Starting Home Assistant discovery")
            discovery.stop()
            discovery.start()
            sleep(60)
            NSLog("Stopping Home Assistant discovery")
            discovery.stop()
        }

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SettingsViewController.HomeAssistantDiscovered(_:)), name:"homeassistant.discovered", object: nil)
        
        form
            +++ Section(header: "Discovered Home Assistants", footer: ""){
                $0.tag = "discoveredInstances"
                $0.hidden = true
            }
        
        
        let pscope = PermissionScope()
        
        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "We use this to let you\r\nsend notifications to your device.")
        
        pscope.addPermission(LocationAlwaysPermission(),
                             message: "We use this to inform\r\nHome Assistant of your device presence.")
        
        form
            +++ Section(header: "", footer: "Format should be protocol://hostname_or_ip:portnumber. NO slashes. Only provide a port number if not using 80/443. Examples: http://192.168.1.2:8123, https://demo.home-assistant.io.")
            <<< URLRow("baseURL") {
                $0.title = "Base URL"
                if let baseURL = prefs.stringForKey("baseURL") {
                    $0.value = NSURL(string: baseURL)
                }
                $0.placeholder = "https://homeassistant.myhouse.com"
            }
            +++ Section(header: "Settings", footer: "")
            <<< PasswordRow("apiPassword") {
                $0.title = "API Password"
                if let apiPass = prefs.stringForKey("apiPassword") {
                    $0.value = apiPass
                }
                $0.placeholder = "password"
            }
            <<< TextRow("deviceId") {
                let cleanModel = UIDevice.currentDevice().model.lowercaseString.stringByReplacingOccurrencesOfString(" ", withString: "")
                $0.placeholder = cleanModel
                $0.title = "Device ID (location tracking)"
                if let deviceId = prefs.stringForKey("deviceId") {
                    $0.value = deviceId
                } else {
                    $0.value = cleanModel
                }
                $0.cell.textField.autocapitalizationType = .None
            }
            <<< SwitchRow("allowAllGroups") {
                $0.title = "Show all groups"
                $0.value = prefs.boolForKey("allowAllGroups")
            }
            <<< ButtonRow() {
                $0.title = "Save"
            }.onCellSelection {_,_ in
                let urlRow: URLRow? = self.form.rowByTag("baseURL")
                let apiPasswordRow: PasswordRow? = self.form.rowByTag("apiPassword")
                let deviceIdRow: TextRow? = self.form.rowByTag("deviceId")
                let allowAllGroupsRow: SwitchRow? = self.form.rowByTag("allowAllGroups")
                
                if let baseURL = urlRow!.value?.absoluteString {
                    print("BaseURL is", baseURL)
                    var apiPass = ""
                    if let pass = apiPasswordRow?.value {
                        apiPass = pass
                    }
                    let APIClientSharedInstance = HomeAssistantAPI(baseAPIUrl: baseURL, APIPassword: apiPass)
                    APIClientSharedInstance.identifyDevice().then { ident -> Void in
                        print("Identified!", ident)
                    }
                    APIClientSharedInstance.GetConfig().then { config -> Void in
                        self.prefs.setValue(config.LocationName, forKey: "location_name")
                        self.prefs.setValue(config.Latitude, forKey: "latitude")
                        self.prefs.setValue(config.Longitude, forKey: "longitude")
                        self.prefs.setValue(config.TemperatureUnit, forKey: "temperature_unit")
                        self.prefs.setValue(config.Timezone, forKey: "time_zone")
                        self.prefs.setValue(config.Version, forKey: "version")
                    }
                } else {
                    print("Error when trying to save")
                }
                
                self.prefs.setValue(urlRow!.value!.absoluteString, forKey: "baseURL")
                self.prefs.setValue(apiPasswordRow!.value!, forKey: "apiPassword")
                self.prefs.setValue(deviceIdRow!.value!, forKey: "deviceId")
                self.prefs.setBool(allowAllGroupsRow!.value!, forKey: "allowAllGroups")
                
                pscope.show({ finished, results in
                    print("got results \(results)")
                    if results[0].status == .Authorized {
                        print("User authorized the use of notifications")
                        UIApplication.sharedApplication().registerForRemoteNotifications()
                    }
                    if finished {
                        print("Finished, resetting API")
                        self.dismissViewControllerAnimated(true, completion: nil)
                        (UIApplication.sharedApplication().delegate as! AppDelegate).initAPI()
                    }
                }, cancelled: { (results) -> Void in
                    print("thing was cancelled")
                    self.dismissViewControllerAnimated(true, completion: nil)
                    (UIApplication.sharedApplication().delegate as! AppDelegate).initAPI()
                })
            }
            
            if let endpointArn = prefs.stringForKey("endpointARN") {
                print("endpoint", endpointArn)
                form
                    +++ Section(header: "Push information", footer: "")
                        <<< TextAreaRow() {
                            $0.placeholder = "EndpointArn"
                            $0.value = endpointArn.componentsSeparatedByString("/").last
                            $0.disabled = true
                    }
            }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func aboutButtonPressed(sender: UIButton) {
        let viewController = AcknowListViewController()
        if let navigationController = self.navigationController {
            navigationController.pushViewController(viewController, animated: true)
        }
    }

    func HomeAssistantDiscovered(notification: NSNotification){
        let discoverySection : Section = self.form.sectionByTag("discoveredInstances")!
        discoverySection.hidden = false
        if let userInfo = notification.userInfo as? [String:AnyObject] {
            let name = userInfo["name"] as! String
            if self.form.rowByTag(name) != nil {
                print("Row already exists, skip!")
            } else {
                let baseUrl = userInfo["baseUrl"] as! String
                let version = userInfo["version"] as! String
                let needsAuth = userInfo["needs_auth"] as! Bool
                discoverySection
                    <<< ButtonRow(name) {
                            $0.title = name
                            $0.cellStyle = UITableViewCellStyle.Subtitle
                        }.cellUpdate { cell, row in
                            cell.textLabel?.textColor = .blackColor()
                            cell.detailTextLabel?.text = baseUrl + " - " + version
                        }.onCellSelection({ cell, row in
                            print("Changed!")
                            let urlRow: URLRow? = self.form.rowByTag("baseURL")
                            urlRow!.value = NSURL(string: baseUrl)
                            urlRow?.updateCell()
                            if needsAuth == false {
                                let apiPasswordRow: PasswordRow? = self.form.rowByTag("apiPassword")
                                apiPasswordRow?.value = ""
                                apiPasswordRow?.hidden = false
                                apiPasswordRow?.evaluateHidden()
                                apiPasswordRow?.updateCell()
                            }
                        })
                self.tableView?.reloadData()
            }
        }
        discoverySection.evaluateHidden()
    }
    
}

