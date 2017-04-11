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
import PromiseKit
import KeychainAccess

class RootTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    let prefs = UserDefaults(suiteName: "group.io.robbie.homeassistant")!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(RootTabBarViewController.StateChangedSSEEvent(_:)),
                                               name:NSNotification.Name(rawValue: "sse.state_changed"),
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
    }

    override func viewDidAppear(_ animated: Bool) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        let keychain = Keychain(service: "io.robbie.homeassistant", accessGroup: "UTQFCBPQRF.io.robbie.HomeAssistant")
        if let baseURL = keychain["baseURL"], let apiPass = keychain["apiPassword"] {
            firstly {
                HomeAssistantAPI.sharedInstance.Setup(baseURL: baseURL, password: apiPass)
                }.then {_ in
                    HomeAssistantAPI.sharedInstance.Connect()
                }.then { _ -> Void in
                    if HomeAssistantAPI.sharedInstance.notificationsEnabled {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    print("Connected!")
                    hud.hide(animated: true)
                    self.loadTabs()
                    return
                }.catch {err -> Void in
                    print("ERROR on connect!!!", err)
                    hud.hide(animated: true)
                    let settingsView = SettingsViewController()
                    settingsView.showErrorConnectingMessage = true
                    settingsView.showErrorConnectingMessageError = err
                    settingsView.doneButton = true
                    let navController = UINavigationController(rootViewController: settingsView)
                    self.present(navController, animated: true, completion: nil)
            }
        } else {
            let settingsView = SettingsViewController()
            settingsView.doneButton = true
            let navController = UINavigationController(rootViewController: settingsView)
            self.present(navController, animated: true, completion: {
                hud.hide(animated: true)
            })
        }
    }

    // swiftlint:disable:next function_body_length
    func loadTabs() {

        self.delegate = self

        let tabBarIconColor = Entity().DefaultEntityUIColor

        var tabViewControllers: [UIViewController] = []

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
            groupView.GroupID = group.ID
            groupView.Order = group.Order.value
            let groupName = group.Auto ? group.Name.capitalized : group.Name
            groupView.title = groupName
            groupView.tabBarItem.title = groupName
            let icon = group.Entities.first!.EntityIcon(width: 30, height: 30, color: tabBarIconColor)
            groupView.tabBarItem = UITabBarItem(title: groupName, image: icon, tag: index)

            if group.Order.value == nil {
                // Save the index now since it should be first time running
                // swiftlint:disable:next force_try
                try! realm.write {
                    group.Order.value = index
                }
            }

            if HomeAssistantAPI.sharedInstance.locationEnabled {
                var rightBarItems: [UIBarButtonItem] = []

                let uploadIcon = getIconForIdentifier("mdi:upload",
                                                      iconWidth: 30,
                                                      iconHeight: 30,
                                                      color: tabBarIconColor)

                rightBarItems.append(UIBarButtonItem(image: uploadIcon,
                                                     style: .plain,
                                                     target: self,
                                                     action: #selector(RootTabBarViewController.sendCurrentLocation(_:))
                    )
                )

                let mapIcon = getIconForIdentifier("mdi:map",
                                                   iconWidth: 30,
                                                   iconHeight: 30,
                                                   color: tabBarIconColor)

                rightBarItems.append(UIBarButtonItem(image: mapIcon,
                                                     style: .plain,
                                                     target: self,
                                                     action: #selector(RootTabBarViewController.openMapView(_:))))

                groupView.navigationItem.setRightBarButtonItems(rightBarItems, animated: true)
            }

            let navController = UINavigationController(rootViewController: groupView)

            tabViewControllers.append(navController)
        }
        let settingsIcon = getIconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)

        let settingsView = SettingsViewController()
        settingsView.tabBarItem = UITabBarItem(title: "Settings", image: settingsIcon, tag: 1)
        settingsView.hidesBottomBarWhenPushed = true

        tabViewControllers.append(UINavigationController(rootViewController: settingsView))
        self.viewControllers = tabViewControllers
        tabViewControllers.removeLast()
        self.customizableViewControllers = tabViewControllers
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          willEndCustomizing viewControllers: [UIViewController], changed: Bool) {

    }

    func tabBarController(_ tabBarController: UITabBarController,
                          didEndCustomizing viewControllers: [UIViewController], changed: Bool) {
        if changed {
            for (index, view) in viewControllers.enumerated() {
                if let navController = view as? UINavigationController {
                    if let groupView = navController.viewControllers[0] as? GroupViewController {
                        let update = ["ID": groupView.GroupID, "Order": index] as [String : Any]
                        // swiftlint:disable:next force_try
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func StateChangedSSEEvent(_ notification: Notification) {
        if let userInfo = (notification as NSNotification).userInfo {
            if let jsonObj = userInfo["jsonObject"] as? [String: Any] {
                if let event = Mapper<StateChangedEvent>().map(JSON: jsonObj) {
                    let new = event.NewState! as Entity
                    let old = event.OldState! as Entity
                    var subtitleString = "\(new.FriendlyName!) is now \(new.State). It was \(old.State)"
                    if let uom = new.UnitOfMeasurement {
                        subtitleString = "\(new.State) \(uom). It was \(old.State) \(String(describing: old.UnitOfMeasurement))"
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
        HomeAssistantAPI.sharedInstance.sendOneshotLocation().then { _ -> Void in
            let alert = UIAlertController(title: "Location updated",
                                          message: "Successfully sent a one shot location to the server",
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            }.catch {error in
                let nserror = error as NSError
                let message = "Failed to send current location to server. The error was \(nserror.localizedDescription)"
                let alert = UIAlertController(title: "Location failed to update",
                                              message: message,
                                              preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
        }
    }
}
