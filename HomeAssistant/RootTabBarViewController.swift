//
//  RootTabBarViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import SwiftyJSON
import MBProgressHUD
import Whisper

class RootTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        delegate = self
        
        let settingsIcon = getIconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30, color: colorWithHexString("#44739E", alpha: 1))
        
        self.moreNavigationController.topViewController!.navigationItem.leftBarButtonItem = UIBarButtonItem(image: settingsIcon, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(RootTabBarViewController.openSettings(_:)))
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RootTabBarViewController.StateChangedSSEEvent(_:)), name:"EntityStateChanged", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        
        var tabViewControllers : [UIViewController] = []
        
        let firstGroupView = GroupViewController()
        firstGroupView.title = "Loading..."
        self.viewControllers = [firstGroupView]
        
        if let APIClientSharedInstance = (UIApplication.sharedApplication().delegate as! AppDelegate).APIClientSharedInstance {
            APIClientSharedInstance.GetBootstrap().then { bootstrap -> Void in
                let allGroups = bootstrap["states"].arrayValue.filter {
                    let entityId = $0["entity_id"].stringValue
                    let entityType = getEntityType(entityId)
                    var shouldReturn = true
                    if entityType != "group" { // We only want groups
                        return false
                    }
                    if $0["attributes"]["hidden"].exists() && $0["attributes"]["hidden"].boolValue == false {
                        shouldReturn = false
                    }
                    if $0["attributes"]["view"].exists() && $0["attributes"]["view"].boolValue == false {
                        shouldReturn = false
                    }
                    if $0["attributes"]["auto"].exists() && $0["attributes"]["auto"].boolValue {
                        shouldReturn = false
                    }
                    return shouldReturn
                }.sort {
                    if $0["entity_id"].stringValue.containsString("group.all_") == true {
                        return false
                    } else {
                        if $0["attributes"]["order"].exists() && $1["attributes"]["order"].exists() {
                            return $0["attributes"]["order"].intValue < $1["attributes"]["order"].intValue
                        } else {
                            return $0["attributes"]["friendly_name"].stringValue < $1["attributes"]["friendly_name"].stringValue
                        }
                    }
                }
                for (index, group) in allGroups.enumerate() {
                    let title = group["attributes"]["friendly_name"].stringValue.capitalizedString
                    let groupView = GroupViewController()
                    groupView.APIClientSharedInstance = APIClientSharedInstance
                    groupView.receivedGroup = group
                    var sendingEntities = [AnyObject]()
                    let filteredEntities = bootstrap["states"].filter {
                        return group["attributes"]["entity_id"].arrayValue.contains($0.1["entity_id"])
                    }
                    for (_,subJson):(String, JSON) in filteredEntities {
                        sendingEntities.append(subJson.object)
                    }
                    groupView.receivedEntities = JSON(sendingEntities)
                    groupView.title = title
                    groupView.tabBarItem.title = title
                    var groupIcon = iconForDomain(getEntityType(group["attributes"]["entity_id"][0].stringValue))
                    if group["attributes"]["icon"].exists() {
                        groupIcon = group["attributes"]["icon"].stringValue
                    }
                    let icon = getIconForIdentifier(groupIcon, iconWidth: 30, iconHeight: 30, color: colorWithHexString("#44739E", alpha: 1))
                    groupView.tabBarItem = UITabBarItem(title: title, image: icon, tag: index)
                    let navController = UINavigationController(rootViewController: groupView)
                    tabViewControllers.append(navController)
                }
                self.viewControllers = tabViewControllers
                MBProgressHUD.hideAllHUDsForView(self.view, animated: true)
            }
        } else {
            print("Skip!")
        }
        let settingsIcon = getIconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30, color: colorWithHexString("#44739E", alpha: 1))
        
        self.moreNavigationController.topViewController!.navigationItem.leftBarButtonItem = UIBarButtonItem(image: settingsIcon, style: UIBarButtonItemStyle.Plain, target: self, action: #selector(RootTabBarViewController.openSettings(_:)))
    }
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        print("Should select viewController: \(viewController.title) ?")
        return true;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func openSettings(sender: UIBarButtonItem) {
        let settingsView = SettingsViewController()
        settingsView.title = "Settings"
        settingsView.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(RootTabBarViewController.closeSettings(_:)))
        let navController = UINavigationController(rootViewController: settingsView)
        self.presentViewController(navController, animated: true, completion: nil)
    }
    
    @IBAction func closeSettings(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    
    func StateChangedSSEEvent(notification: NSNotification){
        let json = JSON(notification.userInfo!)
        let friendly_name = json["data"]["new_state"]["attributes"]["friendly_name"].stringValue
        let newState = json["data"]["new_state"]["state"].stringValue
        var subtitleString = friendly_name+" is now "+newState+". It was "+json["data"]["old_state"]["state"].stringValue
        if json["data"]["new_state"]["attributes"]["unit_of_measurement"].exists() && json["data"]["old_state"]["attributes"]["unit_of_measurement"].exists() {
            subtitleString = newState + " " + json["data"]["new_state"]["attributes"]["unit_of_measurement"].stringValue+". It was "+json["data"]["old_state"]["state"].stringValue + " " + json["data"]["old_state"]["attributes"]["unit_of_measurement"].stringValue
        }
        Whistle(Murmur(title: subtitleString))
//        let icon = generateIconForEntity(json["data"]["new_state"])
//        let announcement = Announcement(title: friendly_name, subtitle: subtitleString, image: icon)
//        Shout(announcement, to: self.navigationController!)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
