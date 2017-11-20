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

// MARK: LocationRow

public final class LocationRow: Row<PushSelectorCell<CLLocation>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = {
            guard let location = $0 else { return "" }
            let fmt = NumberFormatter()
            fmt.maximumFractionDigits = 4
            fmt.minimumFractionDigits = 4
            let latitude = fmt.string(from: NSNumber(value: location.coordinate.latitude))!
            let longitude = fmt.string(from: NSNumber(value: location.coordinate.longitude))!
            return  "\(latitude), \(longitude)"
        }
    }

    override public func customDidSelect() {
        super.customDidSelect()
        guard !isDisabled else { return }

        let vc = MapViewController { _ in }
        vc.row = self
        cell.formViewController()?.navigationController?.pushViewController(vc, animated: true)
        vc.onDismissCallback = { _ in
            vc.navigationController?.popViewController(animated: true)
        }
    }
}

public class MapViewController: UIViewController, TypedRowControllerType, MKMapViewDelegate {

    public var row: RowOf<CLLocation>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    lazy var mapView: MKMapView = { [unowned self] in
        let v = MKMapView(frame: self.view.bounds)
        v.autoresizingMask = UIViewAutoresizing.flexibleWidth.union(UIViewAutoresizing.flexibleHeight)
        return v
        }()

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    convenience public init(_ callback: ((UIViewController) -> Void)?) {
        self.init(nibName: nil, bundle: nil)
        onDismissCallback = callback
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)

        mapView.delegate = self
        mapView.showsUserLocation = true

        if let value = row.value {
            let dropPin = MKPointAnnotation()
            dropPin.coordinate = value.coordinate
            mapView.addAnnotation(dropPin)
            let region = MKCoordinateRegionMakeWithDistance(value.coordinate, 400, 400)
            mapView.setRegion(region, animated: true)
            if value.horizontalAccuracy != 0 {
                let circle = HACircle.init(center: value.coordinate, radius: value.horizontalAccuracy)
                circle.type = "device"
                mapView.add(circle)
            }
        }

        let fmt = NumberFormatter()
        fmt.maximumFractionDigits = 4
        fmt.minimumFractionDigits = 4
        let latitude = fmt.string(from: NSNumber(value: mapView.centerCoordinate.latitude))!
        let longitude = fmt.string(from: NSNumber(value: mapView.centerCoordinate.longitude))!
        title = "\(latitude), \(longitude)"
    }

    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? HACircle {
            let circle = MKCircleRenderer(overlay: overlay)
            if overlay.type == "zone" {
                circle.strokeColor = UIColor.red
                circle.fillColor = UIColor.red.withAlphaComponent(0.1)
                circle.lineWidth = 1
                circle.lineDashPattern = [2, 5]
            } else if overlay.type == "device" {
                circle.strokeColor = UIColor.blue
                circle.fillColor = UIColor.blue.withAlphaComponent(0.1)
                circle.lineWidth = 1
            }
            return circle
        } else {
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
