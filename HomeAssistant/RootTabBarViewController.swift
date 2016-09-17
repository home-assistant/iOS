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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self, selector: #selector(RootTabBarViewController.StateChangedSSEEvent(_:)), name:NSNotification.Name(rawValue: "sse.state_changed"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {

        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)

        self.delegate = self
        
        let tabBarIconColor = colorWithHexString("#44739E", alpha: 1)
        
        var tabViewControllers : [UIViewController] = []
        
        let firstGroupView = GroupViewController()
        firstGroupView.title = "Loading..."
        
        self.viewControllers = [firstGroupView]
        
        if HomeAssistantAPI.sharedInstance.baseAPIURL == "" {
            DispatchQueue.main.async(execute: {
                let settingsView = SettingsViewController()
                settingsView.title = "Settings"
                let navController = UINavigationController(rootViewController: settingsView)
                self.present(navController, animated: true, completion: nil)
            })
        }
        
        let allGroups = realm.objects(Group.self).filter {
            var shouldReturn = true
//            if prefs.bool(forKey: "allowAllGroups") == false {
//                shouldReturn = (!$0.Auto && !$0.Hidden && $0.View)
//                print("$0.Auto: \($0.Auto) !$0.Auto: \(!$0.Auto)")
//                print("$0.Hidden: \($0.Hidden) !$0.Hidden: \(!$0.Hidden)")
//                print("$0.View: \($0.View) !$0.View: \(!$0.View)")
//                print("ShouldReturn is now", shouldReturn)
//            }
            // If all entities are a group, return false
            var groupCheck = [String]()
            for entity in $0.Entities {
                groupCheck.append(entity.Domain)
            }
            let uniqueCheck = Array(Set(groupCheck))
            if uniqueCheck.count == 1 && uniqueCheck[0] == "group" {
                shouldReturn = false
            }
            return shouldReturn
        }.sorted {
            if $0.IsAllGroup == true {
                return false
            } else {
                if $0.Order.value != nil && $1.Order.value != nil {
                    return $0.Order.value! < $1.Order.value!
                } else {
                    return $0.FriendlyName! < $1.FriendlyName!
                }
            }
        }
        for (index, group) in allGroups.enumerated() {
            if group.Entities.count < 1 { continue }
            let groupView = GroupViewController()
            groupView.GroupID = String(group.ID)
            groupView.Order = group.Order.value
            groupView.title = group.Name
            groupView.tabBarItem.title = group.Name
            let icon = group.Entities.first!.EntityIcon(width: 30, height: 30, color: tabBarIconColor)
            groupView.tabBarItem = UITabBarItem(title: group.Name, image: icon, tag: index)
            
            if group.Order.value == nil {
                // Save the index now since it should be first time running
                try! realm.write {
                    group.Order.value = index
                }
            }
            
            if HomeAssistantAPI.sharedInstance.locationEnabled() {
                var rightBarItems : [UIBarButtonItem] = []
                
                let uploadIcon = getIconForIdentifier("mdi:upload", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                
                rightBarItems.append(UIBarButtonItem(image: uploadIcon, style: .plain, target: self, action: #selector(RootTabBarViewController.sendCurrentLocation(_:))))
                
                let mapIcon = getIconForIdentifier("mdi:map", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)
                
                rightBarItems.append(UIBarButtonItem(image: mapIcon, style: .plain, target: self, action: #selector(RootTabBarViewController.openMapView(_:))))
                
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
        
        tabViewControllers.removeLast()
        
        self.customizableViewControllers = tabViewControllers
        
        hud.hide(animated: true)
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        return true;
    }
    
    func tabBarController(_ tabBarController: UITabBarController, willEndCustomizing viewControllers: [UIViewController], changed: Bool) {
        
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didEndCustomizing viewControllers: [UIViewController], changed: Bool) {
        if (changed) {
            for (index, view) in viewControllers.enumerated() {
                if let groupView = (view as! UINavigationController).viewControllers[0] as? GroupViewController {
                    let update = ["ID": groupView.GroupID, "Order": index] as [String : Any]
                    try! realm.write {
                        realm.create(Group.self, value: update as AnyObject, update: true)
                    }
                    print("\(index): \(groupView.tabBarItem.title!) New: \(index) Old: \(groupView.Order!)")
                } else {
                    print("Couldn't cast to a group, must be settings, skipping!")
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func StateChangedSSEEvent(_ notification: Notification){
        if let userInfo = (notification as NSNotification).userInfo {
            if let jsonObj = userInfo["jsonObject"] as? [String: Any] {
                if let event = Mapper<StateChangedEvent>().map(JSON: jsonObj) {
                    let newState = event.NewState! as Entity
                    let oldState = event.OldState! as Entity
                    var subtitleString = "\(newState.FriendlyName!) is now \(newState.State). It was \(oldState.State)"
                    if let uom = newState.UnitOfMeasurement {
                        subtitleString = "\(newState.State) \(uom). It was \(oldState.State) \(oldState.UnitOfMeasurement)"
                    }
                    let _ = Murmur(title: subtitleString)
                }
            }
        }
    }

    func openMapView(_ sender: UIButton) {
        let devicesMapView = DevicesMapViewController()
        
        let navController = UINavigationController(rootViewController: devicesMapView)
        self.present(navController, animated: true, completion: nil)
    }
    
    func sendCurrentLocation(_ sender: UIButton) {
        HomeAssistantAPI.sharedInstance.sendOneshotLocation(notifyString: "One off location update requested").then { success -> Void in
            let alert = UIAlertController(title: "Location updated", message: "Successfully sent a one shot location to the server", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }.catch {error in
            let nserror = error as NSError
            let alert = UIAlertController(title: "Location failed to update", message: "Failed to send current location to server. The error was \(nserror.localizedDescription)", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
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
