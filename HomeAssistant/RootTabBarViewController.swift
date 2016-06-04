//
//  RootTabBarViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MBProgressHUD
import Whisper
import ObjectMapper
import PermissionScope

class RootTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    var deviceTrackerEntities = [Entity]()
    var zoneEntities = [Entity]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(RootTabBarViewController.StateChangedSSEEvent(_:)), name:"sse.state_changed", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {

        MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        
        let tabBarIconColor = colorWithHexString("#44739E", alpha: 1)
        
        var tabViewControllers : [UIViewController] = []
        
        let firstGroupView = GroupViewController()
        firstGroupView.title = "Loading..."
        
        self.viewControllers = [firstGroupView]
        
        if HomeAssistantAPI.sharedInstance.baseAPIURL != "" {
            HomeAssistantAPI.sharedInstance.GetStates().then { states -> Void in
                self.deviceTrackerEntities = states.filter { return $0.Domain == "device_tracker" }
                self.zoneEntities = states.filter { return $0.Domain == "zone" }
                let allGroups = states.filter {
                    var shouldReturn = true
                    if $0.Domain != "group" { // We only want groups
                        return false
                    }
                    let groupZero = $0 as! Group
                    if prefs.boolForKey("allowAllGroups") == false {
                        if groupZero.Hidden == true {
                            shouldReturn = false
                        }
                        if let view = groupZero.Attributes["view"] as? Bool {
                            if view == false {
                                shouldReturn = false
                            }
                        }
                        if let auto = groupZero.Attributes["auto"] as? Bool {
                            if auto == true {
                                shouldReturn = false
                            }
                        }
                    }
                    // If all entities are a group, return false
                    var groupCheck = [String]()
                    for entity in groupZero.EntityIds {
                        groupCheck.append(Entity(id: entity).Domain)
                    }
                    let uniqueCheck = Array(Set(groupCheck))
                    if uniqueCheck.count == 1 && uniqueCheck[0] == "group" {
                        shouldReturn = false
                    }
                    return shouldReturn
                }.sort {
                    let groupZero = $0 as! Group
                    let groupOne = $1 as! Group
                    if groupZero.IsAllGroup == true {
                        return false
                    } else {
                        if groupZero.Order != nil && groupOne.Order != nil {
                            return groupZero.Order < groupOne.Order
                        } else {
                            return groupZero.FriendlyName < groupOne.FriendlyName
                        }
                    }
                }
                for (index, group) in allGroups.enumerate() {
                    let group = (group as! Group)
                    if group.EntityIds.count < 1 { continue }
                    let groupView = GroupViewController()
                    groupView.receivedGroup = group
                    groupView.receivedEntities = states.filter {
                        return group.EntityIds.contains($0.ID)
                    }
                    var friendlyName = "Entity"
                    if let friendly = group.FriendlyName {
                        friendlyName = friendly
                    }
                    groupView.title = friendlyName.capitalizedString
                    groupView.tabBarItem.title = friendlyName.capitalizedString
                    let firstEntity = Entity(id: group.EntityIds[0])
                    var firstEntityIcon = firstEntity.StateIcon()
                    if firstEntity.MobileIcon != nil { firstEntityIcon = firstEntity.MobileIcon! }
                    if firstEntity.Icon != nil { firstEntityIcon = firstEntity.Icon! }
                    let icon = getIconForIdentifier(firstEntityIcon, iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                    groupView.tabBarItem = UITabBarItem(title: friendlyName.capitalizedString, image: icon, tag: index)
                    
                    if HomeAssistantAPI.sharedInstance.locationEnabled() {
                        var rightBarItems : [UIBarButtonItem] = []
                        
                        let uploadIcon = getIconForIdentifier("mdi:upload", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                        
                        rightBarItems.append(UIBarButtonItem(image: uploadIcon, style: .Plain, target: self, action: #selector(RootTabBarViewController.sendCurrentLocation(_:))))
                        
                        let mapIcon = getIconForIdentifier("mdi:map", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                        
                        rightBarItems.append(UIBarButtonItem(image: mapIcon, style: .Plain, target: self, action: #selector(RootTabBarViewController.openMapView(_:))))
                        
                        groupView.navigationItem.setRightBarButtonItems(rightBarItems, animated: true)
                    }
                    
                    let navController = UINavigationController(rootViewController: groupView)
                    
                    tabViewControllers.append(navController)
                }
                let settingsIcon = getIconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                
                let settingsView = SettingsViewController()
                settingsView.title = "Settings"
                settingsView.tabBarItem = UITabBarItem(title: "Settings", image: settingsIcon, tag: 1)
            
                tabViewControllers.append(UINavigationController(rootViewController: settingsView))
                
                self.viewControllers = tabViewControllers
                
                MBProgressHUD.hideAllHUDsForView(self.view, animated: true)
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), {
                let settingsView = SettingsViewController()
                settingsView.title = "Settings"
                let navController = UINavigationController(rootViewController: settingsView)
                self.presentViewController(navController, animated: true, completion: nil)
            })
        }
    }
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        print("Should select viewController: \(viewController.title) ?")
        return true;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(notification: NSNotification){
        if let userInfo = notification.userInfo {
            if let event = Mapper<StateChangedEvent>().map(userInfo["jsonObject"]) {
                let newState = event.NewState! as Entity
                let oldState = event.OldState! as Entity
                var subtitleString = newState.FriendlyName!+" is now "+newState.State+". It was "+oldState.State
                if let newStateSensor = newState as? Sensor {
                    let oldStateSensor = oldState as! Sensor
                    subtitleString = "\(newStateSensor.State) \(newStateSensor.UnitOfMeasurement) . It was \(oldState.State) \(oldStateSensor.UnitOfMeasurement)"
                }
                Whistle(Murmur(title: subtitleString))
            }
        }
    }

    func openMapView(sender: UIButton) {
        let devicesMapView = DevicesMapViewController()
        devicesMapView.devices = deviceTrackerEntities
        devicesMapView.zones = zoneEntities
        
        let navController = UINavigationController(rootViewController: devicesMapView)
        self.presentViewController(navController, animated: true, completion: nil)
    }
    
    func sendCurrentLocation(sender: UIButton) {
        HomeAssistantAPI.sharedInstance.sendOneshotLocation("One off location update requested").then { success -> Void in
            print("Did succeed?", success)
            let alert = UIAlertController(title: "Location updated", message: "Successfully sent a one shot location to the server", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }.error { error in
            let nserror = error as NSError
            let alert = UIAlertController(title: "Location failed to update", message: "Failed to send current location to server. The error was \(nserror.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
        }
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
