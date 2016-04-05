//
//  Utils.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import SwiftyJSON
import FontAwesomeKit
import Alamofire
import PromiseKit
import Haneke

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

func getEntityType(entityId: String) -> String {
    return entityId.componentsSeparatedByString(".")[0]
}

func getIconForIdentifier(iconIdentifier: String, iconWidth: Double, iconHeight: Double, color: UIColor) -> UIImage {
    let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as NSDictionary
    let fixedIconIdentifier = iconIdentifier.stringByReplacingOccurrencesOfString(":", withString: "-")
    let iconCode = iconCodes[fixedIconIdentifier] as? String
    let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
    theIcon.addAttribute(NSForegroundColorAttributeName, value: color)
    return theIcon.imageWithSize(CGSizeMake(CGFloat(iconWidth), CGFloat(iconHeight)))
}

func colorWithHexString(hexString: String, alpha:CGFloat? = 1.0) -> UIColor {
    
    // Convert hex string to an integer
    let hexint = Int(intFromHexString(hexString))
    let red = CGFloat((hexint & 0xff0000) >> 16) / 255.0
    let green = CGFloat((hexint & 0xff00) >> 8) / 255.0
    let blue = CGFloat((hexint & 0xff) >> 0) / 255.0
    let alpha = alpha!
    
    // Create color object, specifying alpha as well
    let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    return color
}

func intFromHexString(hexStr: String) -> UInt32 {
    var hexInt: UInt32 = 0
    // Create scanner
    let scanner: NSScanner = NSScanner(string: hexStr)
    // Tell scanner to skip the # character
    scanner.charactersToBeSkipped = NSCharacterSet(charactersInString: "#")
    // Scan hex value
    scanner.scanHexInt(&hexInt)
    return hexInt
}

func iconForDomain(domain: String) -> String {
    switch (domain) {
    case "alarm_control_panel":
        return "mdi:bell-outline";
    case "automation":
        return "mdi:playlist-play";
    case "binary_sensor":
        return "mdi:radiobox-blank";
    case "camera":
        return "mdi:video";
    case "configurator":
        return "mdi:settings";
    case "conversation":
        return "mdi:text-to-speech";
    case "device_tracker":
        return "mdi:account";
    case "garage_door":
        return "mdi:glassdoor";
    case "group":
        return "mdi:google-circles-communities";
    case "homeassistant":
        return "mdi:home";
    case "input_boolean":
        return "mdi:drawing";
    case "input_select":
        return "mdi:format-list-bulleted";
    case "input_slider":
        return "mdi:ray-vertex";
    case "light":
        return "mdi:lightbulb";
    case "lock":
        return "mdi:lock-open";
    case "media_player":
        return "mdi:cast";
    case "notify":
        return "mdi:comment-alert";
    case "proximity":
        return "mdi:apple-safari";
    case "rollershutter":
        return "mdi:window-closed";
    case "scene":
        return "mdi:google-pages";
    case "script":
        return "mdi:file-document";
    case "sensor":
        return "mdi:eye";
    case "simple_alarm":
        return "mdi:bell";
    case "sun":
        return "mdi:white-balance-sunny";
    case "switch":
        return "mdi:flash";
    case "thermostat":
        return "mdi:nest-thermostat";
    case "updater":
        return "mdi:cloud-upload";
    case "weblink":
        return "mdi:open-in-new";
    default:
        return "mdi:bookmark";
    }
}

func iconForDomainAndState(domain: String, state: String) -> String {
    switch (domain) {
    case "alarm_control_panel":
        return (state == "disarmed") ? "mdi:bell-outline" : "mdi:bell";
    case "automation":
        return "mdi:playlist-play";
    case "binary_sensor":
        return (state == "off") ? "mdi:radiobox-blank" : "mdi:checkbox-marked-circle";
    case "camera":
        return "mdi:video";
    case "configurator":
        return "mdi:settings";
    case "conversation":
        return "mdi:text-to-speech";
    case "device_tracker":
        return "mdi:account";
    case "garage_door":
        return "mdi:glassdoor";
    case "group":
        return "mdi:google-circles-communities";
    case "homeassistant":
        return "mdi:home";
    case "input_boolean":
        return "mdi:drawing";
    case "input_select":
        return "mdi:format-list-bulleted";
    case "input_slider":
        return "mdi:ray-vertex";
    case "light":
        return "mdi:lightbulb";
    case "lock":
        return (state == "unlocked") ? "mdi:lock-open" : "mdi:lock";
    case "media_player":
        return (state != "off" && state != "idle") ? "mdi:cast-connected" : "mdi:cast"
    case "notify":
        return "mdi:comment-alert";
    case "proximity":
        return "mdi:apple-safari";
    case "rollershutter":
        return (state == "open") ? "mdi:window-open" : "mdi:window-closed";
    case "scene":
        return "mdi:google-pages";
    case "script":
        return "mdi:file-document";
    case "sensor":
        return "mdi:eye";
    case "simple_alarm":
        return "mdi:bell";
    case "sun":
        return "mdi:white-balance-sunny";
    case "switch":
        return "mdi:flash";
    case "thermostat":
        return "mdi:nest-thermostat";
    case "updater":
        return "mdi:cloud-upload";
    case "weblink":
        return "mdi:open-in-new";
    default:
        return "mdi:bookmark"
    }
}

func binarySensorIcon(entity: SwiftyJSON.JSON) -> String {
    let activated = (entity["state"].stringValue == "off");
    switch (entity["attributes"]["sensor_class"].stringValue) {
    case "opening":
        return activated ? "mdi:crop-square" : "mdi:exit-to-app";
    case "moisture":
        return activated ? "mdi:water-off" : "mdi:water";
    case "light":
        return activated ? "mdi:brightness-5" : "mdi:brightness-7";
    case "sound":
        return activated ? "mdi:music-note-off" : "mdi:music-note";
    case "vibration":
        return activated ? "mdi:crop-portrait" : "mdi:vibrate";
    case "connectivity":
        return activated ? "mdi:server-network-off" : "mdi:server-network";
    case "safety", "gas", "smoke", "power":
        return activated ? "mdi:verified" : "mdi:alert";
    case "motion":
        return activated ? "mdi:walk" : "mdi:run";
    default:
        return activated ? "mdi:radiobox-blank" : "mdi:checkbox-marked-circle";
    }
}

func stateIcon(entity: SwiftyJSON.JSON) -> String {
    let domain = getEntityType(entity["entity_id"].stringValue)
    if (entity["attributes"]["icon"].exists()) {
        return entity["attributes"]["icon"].stringValue;
    }
    
    if (entity["attributes"]["unit_of_measurement"].exists() && domain == "sensor") {
        let unit = entity["attributes"]["unit_of_measurement"].stringValue;
        if (unit == "°C" || unit == "°F") {
            return "mdi:thermometer";
        } else if (unit == "Mice") {
            return "mdi:mouse-variant";
        }
    } else if (domain == "binary_sensor") {
        return binarySensorIcon(entity);
    }
    
    return iconForDomainAndState(domain, state: entity["state"].stringValue);
}

let entityPicturesCache = Cache<UIImage>(name: "entity_pictures")

func getEntityPicture(entityPictureURL: String) -> Promise<UIImage> {
    return Promise { fulfill, reject in
        let URL = NSURL(string: entityPictureURL)
        let fetcher = NetworkFetcher<UIImage>(URL: URL!)
        entityPicturesCache.fetch(fetcher: fetcher).onSuccess { image in
            fulfill(image.scaledToSize(CGSize(width: 30, height: 30)))
        }
    }
}

func generateIconForEntity(entity: SwiftyJSON.JSON) -> UIImage {
    let entityType = getEntityType(entity["entity_id"].stringValue)
    let iconName = stateIcon(entity)
    var color = colorWithHexString("#44739E", alpha: 1)
    if (entityType == "light" || entityType == "switch" || entityType == "binary_sensor" || entityType == "sun") && (entity["state"].stringValue == "on" || entity["state"].stringValue == "above_horizon") {
        color = colorWithHexString("#DCC91F", alpha: 1)
    }
    if entityType == "light" && entity["state"].stringValue == "on" && entity["attributes"]["rgb_color"].exists() {
        let red = CGFloat(entity["attributes"]["rgb_color"][0].doubleValue/255.0)
        let green = CGFloat(entity["attributes"]["rgb_color"][1].doubleValue/255.0)
        let blue = CGFloat(entity["attributes"]["rgb_color"][2].doubleValue/255.0)
        color = UIColor.init(red: red, green: green, blue: blue, alpha: 1)
    }
    if entity["state"].stringValue == "unavailable" {
        color = colorWithHexString("#bdbdbd", alpha: 1)
    }
    return getIconForIdentifier(iconName, iconWidth: 30, iconHeight: 30, color: color)
}

extension UIImage{
    func scaledToSize(size: CGSize) -> UIImage{
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
        self.drawInRect(CGRectMake(0, 0, size.width, size.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}