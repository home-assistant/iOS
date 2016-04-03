//
//  SecondViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka

class SecondViewController: FormViewController {

    let prefs = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        var baseURL = "https://homeassistant.thegrand.systems"
        var apiPass = "mypassword"
        var deviceId = "iphone"
        if let base = prefs.stringForKey("baseURL") {
            baseURL = base
        }
        if let pass = prefs.stringForKey("apiPassword") {
            apiPass = pass
        }
        if let dID = prefs.stringForKey("deviceId") {
            deviceId = dID
        }
        
        form
            +++ Section(header: "Settings", footer: "")
            <<< URLRow("baseURL") {
                $0.title = "Base URL"
                $0.value = NSURL(string: baseURL)
            }
            <<< TextRow("apiPassword") {
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
                let apiPasswordRow: TextRow? = self.form.rowByTag("apiPassword")
                let deviceIdRow: TextRow? = self.form.rowByTag("deviceId")
                self.prefs.setValue(urlRow!.value!.absoluteString, forKey: "baseURL")
                self.prefs.setValue(apiPasswordRow!.value!, forKey: "apiPassword")
                self.prefs.setValue(deviceIdRow!.value!, forKey: "deviceId")
            }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

