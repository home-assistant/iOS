//
//  EntityAttributesViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import SwiftyJSON

class EntityAttributesViewController: FormViewController {

    var entity: JSON = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if entity["attributes"]["friendly_name"].exists() {
            self.title = entity["attributes"]["friendly_name"].stringValue
        } else {
            self.title = "Attributes"
        }
        
        form +++ Section()
        
        form.last! <<< TextRow("state"){
            $0.title = "State"
            $0.value = entity["state"].stringValue
            $0.disabled = true
        }
        
        for attribute in entity["attributes"] {
            form.last! <<< TextRow(attribute.0){
                $0.title = attribute.0.stringByReplacingOccurrencesOfString("_", withString: " ").capitalizedString
                $0.value = attribute.1.stringValue
                $0.disabled = true
            }
        }
        
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
