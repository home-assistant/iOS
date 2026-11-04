import Combine
import Foundation
#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

final class DevicePoseSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private var cancellables = Set<AnyCancellable>()
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .devicePose,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        Current.hinge.posePublisher
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.signal()
            }
            .store(in: &cancellables)
        #if os(iOS) && !targetEnvironment(macCatalyst)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { _ in
                Self.recordDeviceOrientation()
            }
            .store(in: &cancellables)
        Self.recordDeviceOrientation()
        #endif
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        cancellables.removeAll()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        #endif
        isObserving = false
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private static func recordDeviceOrientation() {
        Current.hinge.setDeviceOrientation(rawValue: UIDevice.current.orientation.rawValue)
    }
    #endif
}
