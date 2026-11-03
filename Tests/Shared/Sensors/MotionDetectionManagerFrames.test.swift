import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Feeds synthetic camera frames to `MotionDetectionManager` and checks the detection state machine.
/// The settings live in the shared app-group defaults, so the suite serializes with other shared-state tests.
@Suite(.sharedState)
struct MotionDetectionManagerFramesTests {
    private static let keys = [
        "motion_detection_frame_rate",
        "motion_detection_area_threshold",
        "motion_detection_clear_delay",
    ]

    /// The manager calls back on the main queue while the test polls `changes` from its own task, so
    /// both sides go through the lock.
    private final class Observer: MotionDetectionObserver, @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Bool] = []

        var changes: [Bool] {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }

        func motionStateDidChange(for manager: MotionDetectionManager) {
            let detected = manager.isMotionDetected
            lock.lock()
            recorded.append(detected)
            lock.unlock()
        }
    }

    private func withRestoredSettings(_ body: () async throws -> Void) async rethrows {
        let prefs = Current.settingsStore.prefs
        let previous = Self.keys.map { prefs.object(forKey: $0) }
        defer {
            for (key, value) in zip(Self.keys, previous) {
                prefs.set(value, forKey: key)
            }
        }
        try await body()
    }

    private func frame(luma: UInt8) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            48,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attributes,
            &pixelBuffer
        )
        let buffer = try #require(pixelBuffer, "CVPixelBufferCreate failed: \(status)")
        CVPixelBufferLockBaseAddress(buffer, [])
        for plane in 0 ..< CVPixelBufferGetPlaneCount(buffer) {
            if let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) {
                let size = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane) * CVPixelBufferGetHeightOfPlane(
                    buffer,
                    plane
                )
                memset(base, Int32(plane == 0 ? luma : 128), size)
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &format
        )
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        try CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: #require(format),
            sampleTiming: &timing,
            sampleBufferOut: &sample
        )
        return try #require(sample)
    }

    /// `captureOutput` never touches the connection, and one can't be built without a capture device.
    private var placeholderConnection: AVCaptureConnection {
        unsafeBitCast(NSObject(), to: AVCaptureConnection.self)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func settingsDefaultAndPersist() async {
        await withRestoredSettings {
            let prefs = Current.settingsStore.prefs
            Self.keys.forEach { prefs.removeObject(forKey: $0) }
            let manager = MotionDetectionManager()
            #expect(manager.frameRate == 8)
            #expect(manager.areaThresholdPercent == 40)
            #expect(manager.clearDelay == 15)

            manager.frameRate = 2
            manager.areaThresholdPercent = 10
            manager.clearDelay = 3
            #expect(manager.frameRate == 2)
            #expect(manager.areaThresholdPercent == 10)
            #expect(manager.clearDelay == 3)

            let attributes = manager.attributes
            #expect(attributes["Frame Rate"] as? Double == 2)
            #expect(attributes["Last Motion"] as? String == "never")
            #expect(!manager.isMotionDetected)
            #expect(manager.lastMotionDate == nil)
            #expect(manager.lastChangedRatio == 0)
        }
    }

    @Test func changingFramesFlagsMotionAndClearsAfterTheDelay() async throws {
        try await withRestoredSettings {
            let manager = MotionDetectionManager()
            manager.frameRate = 1_000_000
            manager.areaThresholdPercent = 10
            manager.clearDelay = 0.05

            let observer = Observer()
            manager.register(observer: observer)
            defer { manager.unregister(observer: observer) }

            let output = AVCaptureVideoDataOutput()
            let dark = try frame(luma: 10)
            let bright = try frame(luma: 240)

            // Identical frames never count as motion.
            manager.captureOutput(output, didOutput: dark, from: placeholderConnection)
            manager.captureOutput(output, didOutput: dark, from: placeholderConnection)
            #expect(manager.lastChangedRatio == 0)
            #expect(!manager.isMotionDetected)

            var luma = true
            let deadline = Date().addingTimeInterval(10)
            while !manager.isMotionDetected, Date() < deadline {
                manager.captureOutput(output, didOutput: luma ? bright : dark, from: placeholderConnection)
                luma.toggle()
                try await Task.sleep(for: .milliseconds(5))
            }
            #expect(manager.isMotionDetected)
            #expect(manager.lastChangedRatio == 1)
            #expect(manager.lastMotionDate != nil)
            #expect(manager.attributes["Last Motion"] as? String != "never")

            // The clear timer flips the state back once no more motion arrives.
            try await waitUntil { !manager.isMotionDetected }
            try await waitUntil {
                let changes = observer.changes
                return changes.contains(true) && changes.last == false
            }
        }
    }

    @Test func registrationLifecycleWithoutACamera() async throws {
        try await withRestoredSettings {
            let manager = MotionDetectionManager()
            let first = Observer()
            let second = Observer()
            manager.register(observer: first)
            manager.register(observer: second)
            manager.refreshFrameRate()
            manager.refreshVideoOrientation()
            manager.unregister(observer: first)
            manager.unregister(observer: second)
            // Unregistering the last observer resets the state on the main queue.
            await MainActor.run {}
            #expect(!manager.isMotionDetected)
            #expect(manager.canDetectMotion == (AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            ) != nil))
        }
    }
}
