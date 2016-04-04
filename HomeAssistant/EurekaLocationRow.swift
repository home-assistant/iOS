//
//  EurekaLocationRow.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/4/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import MapKit

//MARK: LocationRow

public final class LocationRow : SelectorRow<CLLocation, PushSelectorCell<CLLocation>, MapViewController>, RowType {
    
    public required init(tag: String?) {
        super.init(tag: tag)
        presentationMode = .Show(controllerProvider: ControllerProvider.Callback { return MapViewController(){ _ in } }, completionCallback: { vc in vc.navigationController?.popViewControllerAnimated(true) })
        displayValueFor = {
            guard let location = $0 else { return "" }
            let fmt = NSNumberFormatter()
            fmt.maximumFractionDigits = 4
            fmt.minimumFractionDigits = 4
            let latitude = fmt.stringFromNumber(location.coordinate.latitude)!
            let longitude = fmt.stringFromNumber(location.coordinate.longitude)!
            return  "\(latitude), \(longitude)"
        }
    }
}

public class MapViewController : UIViewController, TypedRowControllerType, MKMapViewDelegate {
    
    public var row: RowOf<CLLocation>!
    public var completionCallback : ((UIViewController) -> ())?
    
    lazy var mapView : MKMapView = { [unowned self] in
        let v = MKMapView(frame: self.view.bounds)
        v.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
        return v
        }()
    
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience public init(_ callback: (UIViewController) -> ()){
        self.init(nibName: nil, bundle: nil)
        completionCallback = callback
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        
        mapView.delegate = self

        if let value = row.value {
            let region = MKCoordinateRegionMakeWithDistance(value.coordinate, 400, 400)
            mapView.setRegion(region, animated: true)
        } else {
            mapView.showsUserLocation = true
        }
        updateTitle()
        
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let newPin = MKPointAnnotation()
        newPin.coordinate = mapView.centerCoordinate
        newPin.title = row?.title;
        mapView.addAnnotation(newPin)
    }
    
    
    func updateTitle(){
        let fmt = NSNumberFormatter()
        fmt.maximumFractionDigits = 4
        fmt.minimumFractionDigits = 4
        let latitude = fmt.stringFromNumber(mapView.centerCoordinate.latitude)!
        let longitude = fmt.stringFromNumber(mapView.centerCoordinate.longitude)!
        title = "\(latitude), \(longitude)"
    }
    
//    public func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
//        ellipsisLayer.transform = CATransform3DMakeScale(0.5, 0.5, 1)
//        UIView.animateWithDuration(0.2, animations: { [weak self] in
//            self?.pinView.center = CGPointMake(self!.pinView.center.x, self!.pinView.center.y - 10)
//        })
//    }
    
//    public func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
//        ellipsisLayer.transform = CATransform3DIdentity
//        UIView.animateWithDuration(0.2, animations: { [weak self] in
//            self?.pinView.center = CGPointMake(self!.pinView.center.x, self!.pinView.center.y + 10)
//        })
//        updateTitle()
//    }
}