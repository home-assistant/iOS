import Foundation

#if os(iOS)
import AVFoundation
import UIKit

public extension AVCaptureVideoOrientation {
    /// The video orientation that keeps captured frames upright for a device held in
    /// `deviceOrientation`, or `nil` when the device orientation says nothing about
    /// which way is up (`.faceUp`, `.faceDown`, `.unknown`).
    ///
    /// The two landscape cases swap: `UIDeviceOrientation` names them after which way
    /// the *device* was rotated, while `AVCaptureVideoOrientation` names them after
    /// where the resulting *image* has its bottom edge. Rotating the device to the
    /// left leaves the camera looking out of what it calls the right-hand landscape.
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}
#endif
