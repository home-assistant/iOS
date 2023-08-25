import AVFoundation
import Communicator
import Foundation
import PromiseKit
import Shared
import WatchKit

class AssistInterfaceController: WKInterfaceController {
    @IBOutlet var inputCommand: WKInterfaceLabel!
    @IBOutlet var assistResponse: WKInterfaceLabel!

    private var audioRecorder: AVAudioRecorder?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        requestInput()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func didTapAssist() {
        requestInput()
    }

    private func startRecording() {
        let recordingName = "audio.m4a"
        guard let dirPath = getAppGroupDirectory() else {
            print("Failed to get app group directory")
            return
        }
        let pathArray = [dirPath, recordingName]
        guard let filePath = URL(string: pathArray.joined(separator: "")) else { return }

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            print("Recording Failed")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
    }

    private func getAppGroupDirectory() -> String? {
        let dirPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)
        return dirPath?.absoluteString
    }

    private func requestInput() {
        if audioRecorder?.isRecording ?? false {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func assist(audioData: Data) {
        enum SendError: Error {
            case notImmediate
            case phoneFailed
        }

        firstly { () -> Promise<Void> in
            Promise { seal in
                guard Communicator.shared.currentReachability == .immediatelyReachable else {
                    seal.reject(SendError.notImmediate)
                    return
                }

                Current.Log.verbose("Signaling assist pressed via phone")
                let actionMessage = InteractiveImmediateMessage(
                    identifier: "AssistRequest",
                    content: ["Input": audioData],
                    reply: { [weak self] message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        guard let answer = message.content["answer"] as? String,
                              let inputText = message.content["inputText"] as? String else { return }
                        self?.assistResponse.setText(answer)
                        self?.inputCommand.setText(inputText)
                        seal.fulfill(())
                    }
                )

                Current.Log.verbose("Sending AssistRequest message \(actionMessage)")
                Communicator.shared.send(actionMessage, errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            }
        }.recover { error -> Promise<Void> in
            Current.Log.error("recovering error \(error) by trying locally")
            return .value(())
        }.done {
            //
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
        }
    }
}

extension AssistInterfaceController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ audioRecorder: AVAudioRecorder, successfully success: Bool) {
        if success {
            print(audioRecorder.url.absoluteString)
            guard let data = try? Data(contentsOf: audioRecorder.url) else {
                print("Failed to convert audio to data")
                return
            }
            assist(audioData: data)
        }
    }
}
