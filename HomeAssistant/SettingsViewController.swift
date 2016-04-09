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

class SettingsViewController: FormViewController {

    let prefs = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        let aboutButton = UIBarButtonItem(title: "About", style: .Plain, target: self, action: Selector(""))
//        
//        self.navigationItem.rightBarButtonItem = aboutButton
        
        form
            +++ Section(header: "Settings", footer: "Format should be protocol://hostname_or_ip:portnumber. NO slashes. Only provide a port number if not using 80/443. Examples: http://192.168.1.2:8123, https://demo.home-assistant.io.")
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
                $0.title = "Device ID (location tracking)"
                if let deviceId = prefs.stringForKey("deviceId") {
                    $0.value = deviceId
                }
                $0.placeholder = "iphone"
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
                self.prefs.setValue(urlRow!.value!.absoluteString, forKey: "baseURL")
                self.prefs.setValue(apiPasswordRow!.value!, forKey: "apiPassword")
                self.prefs.setValue(deviceIdRow!.value!, forKey: "deviceId")
                self.prefs.setBool(allowAllGroupsRow!.value!, forKey: "allowAllGroups")
                let pscope = PermissionScope()
                
                pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                    message: "We use this to let you\r\nsend notifications to your device.")
                pscope.addPermission(LocationAlwaysPermission(),
                    message: "We use this to inform\r\nHome Assistant of your presence.")
                
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
                self.form.last!
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


}

