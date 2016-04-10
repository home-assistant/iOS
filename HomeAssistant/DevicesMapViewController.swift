//
//  DevicesMapViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MapKit

class DevicesMapViewController: UIViewController, MKMapViewDelegate {

    var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let mapView = MKMapView()
        
        mapView.mapType = .Standard
        mapView.frame = view.frame
        mapView.delegate = self
        view.addSubview(mapView)
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
