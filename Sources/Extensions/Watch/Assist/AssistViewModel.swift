import AVFoundation
import Communicator
import Foundation
import HAKit
import PromiseKit
import Shared
import Starscream
import SwiftUI
import WatchKit

@available(watchOS 7.0, *)
extension AssistViewModel: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
        print(event)
    }
}

@available(watchOS 7.0, *)
class AssistViewModel: NSObject, ObservableObject {
    struct ChatMessage: Hashable {
        enum Sender {
            case assist
            case user
        }

        let id = UUID().uuidString
        let message: String
        let sender: Sender
    }

    enum MicrophoneIcons {
        static var microphoneIcon = "mic.circle.fill"
        static var microphoneLoadingIcon = "circle.dotted.circle.fill"
        static var microphoneInProgressIcon = "waveform"
    }

    private var audioRecorder: AVAudioRecorder?
    private var silenceTimer: Timer?
    private let currentWKInterface = WKInterfaceDevice.current()
    private var firstLaunch = true

    @Published var chatMessages: [ChatMessage] = []
    @Published var microphoneIcon: String = MicrophoneIcons.microphoneIcon

    private var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        return URLSession(configuration: config)
    }

    private var socket: WebSocket?
    private var webSocketTask: URLSessionWebSocketTask?
    func requestInput() {
//        debugAlert(message: "Request input")
//        // Create a WebSocketTask
//        session.reset {
//
//        }

//        socket?.disconnect()
//        var request = URLRequest(url: URL(string: "ws://192.168.68.148:8123/api/websocket")!)
//        request.networkServiceType = .voice
//        request.timeoutInterval = 5
//        socket = WebSocket(request: request)
//        socket?.delegate = self
//        socket?.connect()

//
        session.configuration.networkServiceType = .voice
//        session.
        webSocketTask = session.webSocketTask(with: URL(string: "ws://192.168.68.148:8123/api/websocket")!)
        webSocketTask?.resume()
//        webSocketTask.send(.string("hello")) { [weak self] error in
//            self?.debugAlert(message: "send error: \(error)")
//            print(error)
//        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            print("Socket STATE: \(self?.webSocketTask?.state.rawValue)")
        }

        webSocketTask?.sendPing(pongReceiveHandler: { error in
            print("PONG error: \(error)")
        })

        webSocketTask?.receive { [weak self] result in
            print(result)
            switch result {
            case .success(let message):
                self?.debugAlert(message: "Message: \(message)")
                print(message)

                // Continue receiving messages
                //                self.webSocketTask.receive(completionHandler: receiveHandler)

            case .failure(let error):
                self?.debugAlert(message: "WebSocket error: \(error)")
                print("WebSocket error: \(error)")
            }
        }

        // Send a message to the WebSocket server
//        let message = URLSessionWebSocketTask.Message.string("Hello, server!")
//        webSocketTask.send(message) { error in
//            if let error = error {
//                print("WebSocket send error: \(error)")
//            } else {
//                print("Message sent successfully.")
//            }
//        }

//        if let firstServer = Current.servers.all.first {
//            let connection = Current.api(for: firstServer).connection
//            connection.connect()
//            Current.webhooks
//
        ////            let request = HARequest(type: HARequestType(stringLiteral: "assist_pipeline/pipeline/list"))
        ////            let requestConnection = connection.send(request)
        ////
        ////            requestConnection.promise.pipe { result in
        ////                print(result)
        ////            }
//        } else {
//            print(Current.servers.all)
//        }
//
        ////        if audioRecorder?.isRecording ?? false {
        ////            stopRecording()
        ////        } else {
        ////            startRecording()
        ////        }
    }

    private func debugAlert(message: String) {
        // Get the top controller
        if let topController = WKExtension.shared().visibleInterfaceController {
            // Show an alert
            topController.presentAlert(
                withTitle: "Alert",
                message: message,
                preferredStyle: .alert,
                actions: [WKAlertAction(title: "OK", style: .default) {}]
            )
        } else {
            print("No visible interface controller found.")
        }
    }

    private func startRecording() {
        let recordingName = "audio.m4a"
        guard let dirPath = getAppGroupDirectory() else {
            Current.Log.error("Failed to get app group directory")
            currentWKInterface.play(.failure)
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
                currentWKInterface.play(.success)
            }
        } catch {
            Current.Log.error("Recording Failed")
            updateMicrophoneState(.standard)
            currentWKInterface.play(.failure)
        }
    }

    private func appendChatMessage(data: AssistConversationData) {
        chatMessages.append(.init(
            message: data.content,
            sender: data.type == .input ? .user : .assist
        ))
        currentWKInterface.play(.notification)
    }

    private func updateMicrophoneState(_ state: AssistMicStates) {
        switch state {
        case .standard:
            microphoneIcon = MicrophoneIcons.microphoneIcon
        case .loading:
            microphoneIcon = MicrophoneIcons.microphoneLoadingIcon
            currentWKInterface.play(.click)
        case .inProgress:
            microphoneIcon = MicrophoneIcons.microphoneInProgressIcon
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

    private func assist(audioData: Data) {
//        enum SendError: Error {
//            case notImmediate
//            case phoneFailed
//        }
//
//        firstly { () -> Promise<Void> in
//            Promise { seal in
//                guard Communicator.shared.currentReachability == .immediatelyReachable else {
//                    seal.reject(SendError.notImmediate)
//                    return
//                }
//
//                Current.Log.verbose("Signaling assist pressed via phone")
//                let actionMessage = InteractiveImmediateMessage(
//                    identifier: "AssistRequest",
//                    content: ["Input": audioData],
//                    reply: { [weak self] message in
//                        Current.Log.verbose("Received reply dictionary \(message)")
//                        guard let answer = message.content["answer"] as? String,
//                              let inputText = message.content["inputText"] as? String else { return }
//                        self?.appendChatMessage(data: .init(content: inputText, type: .input))
//                        self?.appendChatMessage(data: .init(content: answer, type: .output))
//                        seal.fulfill(())
//                    }
//                )
//
//                Current.Log.verbose("Sending AssistRequest message \(actionMessage)")
//                Communicator.shared.send(actionMessage, errorHandler: { error in
//                    Current.Log.error("Received error when sending immediate message \(error)")
//                    seal.reject(error)
//                })
//            }
//        }.recover { error -> Promise<Void> in
//            Current.Log.error("recovering error \(error) by trying locally")
//            return .value(())
//        }.done { [weak self] in
//            self?.updateMicrophoneState(.standard)
//        }.catch { [weak self] err in
//            Current.Log.error("Error during action event fire: \(err)")
//            self?.updateMicrophoneState(.standard)
//        }
    }
}

@available(watchOS 7, *)
extension AssistViewModel: AVAudioRecorderDelegate {
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
