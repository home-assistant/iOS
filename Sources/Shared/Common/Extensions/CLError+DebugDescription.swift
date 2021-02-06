import CoreLocation
import Foundation

public extension CLError {
    var debugDescription: String {
        switch code {
        case CLError.locationUnknown:
            return L10n.ClError.Description.locationUnknown
        case CLError.denied:
            return L10n.ClError.Description.denied
        case CLError.network:
            return L10n.ClError.Description.network
        case CLError.headingFailure:
            return L10n.ClError.Description.headingFailure
        case CLError.regionMonitoringDenied:
            return L10n.ClError.Description.regionMonitoringDenied
        case CLError.regionMonitoringFailure:
            return L10n.ClError.Description.regionMonitoringFailure
        case CLError.regionMonitoringSetupDelayed:
            return L10n.ClError.Description.regionMonitoringSetupDelayed
        case CLError.regionMonitoringResponseDelayed:
            return L10n.ClError.Description.regionMonitoringResponseDelayed
        case CLError.geocodeFoundNoResult:
            return L10n.ClError.Description.geocodeFoundNoResult
        case CLError.geocodeFoundPartialResult:
            return L10n.ClError.Description.geocodeFoundPartialResult
        case CLError.geocodeCanceled:
            return L10n.ClError.Description.geocodeCanceled
        case CLError.deferredFailed:
            return L10n.ClError.Description.deferredFailed
        case CLError.deferredNotUpdatingLocation:
            return L10n.ClError.Description.deferredNotUpdatingLocation
        case CLError.deferredAccuracyTooLow:
            return L10n.ClError.Description.deferredAccuracyTooLow
        case CLError.deferredDistanceFiltered:
            return L10n.ClError.Description.deferredDistanceFiltered
        case CLError.deferredCanceled:
            return L10n.ClError.Description.deferredCanceled
        case CLError.rangingUnavailable:
            return L10n.ClError.Description.rangingUnavailable
        case CLError.rangingFailure:
            return L10n.ClError.Description.rangingFailure
        default:
            return L10n.ClError.Description.unknown
        }
    }
}
