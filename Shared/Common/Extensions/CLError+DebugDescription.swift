//
//  CLError+DebugDescription.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 6/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreLocation

extension CLError {
    public var debugDescription: String {
        switch self.code {
        case CLError.locationUnknown:
            return "The location manager was unable to obtain a location value right now."
        case CLError.denied:
            return "Access to the location service was denied by the user."
        case CLError.network:
            return "The network was unavailable or a network error occurred."
        case CLError.headingFailure:
            return "The heading could not be determined."
        case CLError.regionMonitoringDenied:
            return "Access to the region monitoring service was denied by the user."
        case CLError.regionMonitoringFailure:
            return "A registered region cannot be monitored."
        case CLError.regionMonitoringSetupDelayed:
            return "Core Location could not initialize the region monitoring feature immediately."
        case CLError.regionMonitoringResponseDelayed:
            return "Core Location will deliver events but they may be delayed."
        case CLError.geocodeFoundNoResult:
            return "The geocode request yielded no result."
        case CLError.geocodeFoundPartialResult:
            return "The geocode request yielded a partial result."
        case CLError.geocodeCanceled:
            return "The geocode request was canceled."
        case CLError.deferredFailed:
            return "The location manager did not enter deferred mode for an unknown reason."
        case CLError.deferredNotUpdatingLocation:
            return "The manager did not enter deferred mode since updates were already disabled/paused."
        case CLError.deferredAccuracyTooLow:
            return "Deferred mode is not supported for the requested accuracy."
        case CLError.deferredDistanceFiltered:
            return "Deferred mode does not support distance filters."
        case CLError.deferredCanceled:
            return "The request for deferred updates was canceled by your app or by the location manager."
        case CLError.rangingUnavailable:
            return "Ranging is disabled."
        case CLError.rangingFailure:
            return "A general ranging error occurred."
        default:
            return "Unknown Core Location error"
        }
    }
}
