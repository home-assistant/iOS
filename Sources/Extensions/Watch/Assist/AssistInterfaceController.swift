import AVFoundation
import Communicator
import Foundation
import PromiseKit
import Shared
import WatchKit

class AssistInterfaceController: WKInterfaceController {
    @IBOutlet private var chatTable: WKInterfaceTable!

    static var controllerIdentifier = "Assist"

    private var audioRecorder: AVAudioRecorder?
    private var firstLaunch = true
    private var silenceTimer: Timer?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        setupMicButton()
        startRecording()
    }

    override func willActivate() {
        super.willActivate()
    }

    override func didDeactivate() {
        super.didDeactivate()
        popToRootController()
    }

    private func setupMicButton() {
        chatTable.insertRows(at: IndexSet(integer: chatTable.numberOfRows), withRowType: AssistMicRowController.rowType)
        let newRowIndex = chatTable.numberOfRows - 1
        guard let row = chatTable.rowController(at: newRowIndex) as? AssistMicRowController else { return }
        row.action = { [weak self] in
            self?.requestInput()
        }
    }

    private func addRowToTable(data: AssistRowControllerData) {
        let newRowIndex = chatTable.numberOfRows - 1
        chatTable.insertRows(at: IndexSet(integer: newRowIndex), withRowType: AssistRowController.rowType)

        let justInsertedRowIndex = chatTable.numberOfRows - 2
        guard let row = chatTable.rowController(at: justInsertedRowIndex) as? AssistRowController else { return }

        row.setContent(data: data)
        let lastRowIndex = chatTable.numberOfRows - 1
        chatTable.scrollToRow(at: lastRowIndex)
    }

    private func updateMicrophoneState(_ state: AssistMicRowControllerStates) {
        guard let row = chatTable.rowController(at: chatTable.numberOfRows - 1) as? AssistMicRowController else { return }
        row.updateState(state)
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
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            updateMicrophoneState(.inProgress)

            // TODO: Remove this workaround and find out why record session ends automatically on first launch
            if firstLaunch {
                firstLaunch = false
                startRecording()
            } else {
                startCheckingForSilence()
            }
        } catch {
            Current.Log.error("Recording Failed")
            updateMicrophoneState(.standard)
        }
    }

    private func startCheckingForSilence() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let audioRecorder = self.audioRecorder,
                  audioRecorder.isRecording else { return }

            audioRecorder.updateMeters()
            let averagePower = audioRecorder.averagePower(forChannel: 0)

            if averagePower < -40.000 {
                self.stopRecording()
                self.silenceTimer?.invalidate()
            }
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        updateMicrophoneState(.standard)
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
                        self?.addRowToTable(data: .init(content: inputText, type: .input))
                        self?.addRowToTable(data: .init(content: answer, type: .output))
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
        }.done { [weak self] in
            self?.updateMicrophoneState(.standard)
        }.catch { [weak self] err in
            Current.Log.error("Error during action event fire: \(err)")
            self?.updateMicrophoneState(.standard)
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
            updateMicrophoneState(.loading)
        } else {
            updateMicrophoneState(.standard)
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Current.Log.error(error)
    }

    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder) {
        Current.Log.error("audioRecorderEndInterruption")
    }

    func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Current.Log.error("audioRecorderBeginInterruption")
    }

    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withFlags flags: Int) {
        Current.Log.error("audioRecorderEndInterruption withFlags \(flags)")
    }

    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        Current.Log.error("audioRecorderBeginInterruption withOptions \(flags)")
    }
}
