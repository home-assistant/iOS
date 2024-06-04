//
//  WatchAudioRecorder.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 04/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import AVFoundation
import Combine

protocol WatchAudioRecorderDelegate: AnyObject {
    func didStartRecording()
    func didStopRecording()
    func didFinishRecording(audioURL: URL)
    func didFailRecording(error: Error)
}

final class WatchAudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 3.0
    private let silenceLevel: Float = -50.0

    weak var delegate: WatchAudioRecorderDelegate?

    private var firstLaunch = true

    func startRecording() {
        if audioRecorder?.isRecording ?? false {
            stopRecording()
            return
        }
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
            ]

            let url = getAudioFileURL()
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
//            if firstLaunch {
//                firstLaunch = false
//                startRecording()
//            } else {
                startMonitoringAudioLevels()
                delegate?.didStartRecording()
//            }
        } catch {
            delegate?.didFailRecording(error: error)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        delegate?.didStopRecording()
    }

    private func getAudioFileURL() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("assist.m4a")
    }

    private func startMonitoringAudioLevels() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let audioRecorder = self.audioRecorder else { return }
            audioRecorder.updateMeters()

            let averagePower = audioRecorder.averagePower(forChannel: 0)
            print(self.silenceLevel)
            print(averagePower)
            if averagePower < self.silenceLevel {
                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceThreshold, repeats: false) { [weak self] _ in
                    self?.stopRecording()
                }
            } else {
                self.silenceTimer?.invalidate()
            }
        }
    }
}

extension WatchAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        delegate?.didFinishRecording(audioURL: getAudioFileURL())
        print(getAudioFileURL())
    }
}
