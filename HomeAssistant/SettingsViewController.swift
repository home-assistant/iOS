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
        
        var baseURL = "https://homeassistant.thegrand.systems"
        var apiPass = "mypassword"
        var deviceId = "iphone"
        var endpointARN = "N/A"
        if let base = prefs.stringForKey("baseURL") {
            baseURL = base
        }
        if let pass = prefs.stringForKey("apiPassword") {
            apiPass = pass
        }
        if let dID = prefs.stringForKey("deviceId") {
            deviceId = dID
        }
        if let eARN = prefs.stringForKey("endpointARN") {
            endpointARN = eARN
        }
        
        let splitARN = endpointARN.componentsSeparatedByString("/").last
        
        form
            +++ Section(header: "Settings", footer: "Format should be protocol://hostname_or_ip:portnumber. NO slashes. Only provide a port number if not using 80/443. Examples: http://192.168.1.2:8123, https://demo.home-assistant.io.")
            <<< URLRow("baseURL") {
                $0.title = "Base URL"
                $0.value = NSURL(string: baseURL)
            }
            +++ Section(header: "Settings", footer: "")
            <<< PasswordRow("apiPassword") {
                $0.title = "API Password"
                $0.value = apiPass
            }
            <<< TextRow("deviceId") {
                $0.title = "Device ID (location tracking)"
                $0.value = deviceId
            }
            <<< ButtonRow() {
                $0.title = "Save"
            }.onCellSelection {_,_ in 
                let urlRow: URLRow? = self.form.rowByTag("baseURL")
                let apiPasswordRow: PasswordRow? = self.form.rowByTag("apiPassword")
                let deviceIdRow: TextRow? = self.form.rowByTag("deviceId")
                self.prefs.setValue(urlRow!.value!.absoluteString, forKey: "baseURL")
                self.prefs.setValue(apiPasswordRow!.value!, forKey: "apiPassword")
                self.prefs.setValue(deviceIdRow!.value!, forKey: "deviceId")
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
            
            if endpointARN != "N/A" {
                self.form.last!
                    +++ Section(header: "Push information", footer: "")
                        <<< TextAreaRow() {
                            $0.placeholder = "EndpointArn"
                            $0.value = splitARN
                            $0.disabled = true
                    }
            }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

