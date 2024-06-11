//
//  WatchCommunicatorService.swift
//  App
//
//  Created by Bruno Pantaleão on 07/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import Communicator
import PromiseKit
import ObjectMapper

final class WatchCommunicatorService {
    enum WatchAssistCommunicatorError: Error {
        case pipelinesFetchFailed
    }

    // Assist
    private var assistService: AssistServiceProtocol?
    private var pendingAudioData: Data?

    func setup() {
        Current.servers.add(observer: self)

        // This directly mutates the data structure for observations to avoid race conditions.
        Communicator.State.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        WatchState.observations.store[.init(queue: .main)] = { watchState in
            Current.Log.verbose("Watch state changed: \(watchState)")
            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        setupMessages()

        Blob.observations.store[.init(queue: .main)] = { [weak self] blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            if blob.identifier == InteractiveImmediateMessages.assistAudioData.rawValue {
                self?.assistAudioData(blob: blob)
            }
        }

        Context.observations.store[.init(queue: .main)] = { context in
            Current.Log.verbose("Received context: \(context.content.keys) \(context.content)")

            if let modelIdentifier = context.content["watchModel"] as? String {
                Current.crashReporter.setUserProperty(value: modelIdentifier, name: "PairedAppleWatch")
            }
        }

        _ = Communicator.shared
    }

    private func setupMessages() {
        InteractiveImmediateMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            Current.Log.verbose("Received \(message.identifier) \(message) \(message.content)")

            guard let self, let messageId = InteractiveImmediateMessages(rawValue: message.identifier) else {
                Current.Log
                    .error(
                        "Received InteractiveImmediateMessage not mapped in InteractiveImmediateMessages: \(message.identifier)"
                    )
                return
            }

            switch messageId {
            case .actionRowPressed:
                self.actionRowPressed(message: message)
            case .pushAction:
                pushAction(message: message)
            case .assistPipelinesFetch:
                assistPipelinesFetch(message: message)
            case .assistAudioData:
                // This will be handled by Blob observation due to amount of data
                break
            }
        }
    }

    private func actionRowPressed(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.actionRowPressedResponse.rawValue
        guard let actionID = message.content["ActionID"] as? String,
              let action = Current.realm().object(ofType: Action.self, forPrimaryKey: actionID),
              let server = Current.servers.server(for: action) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
            return
        }

        firstly {
            Current.api(for: server).HandleAction(actionID: actionID, source: .Watch)
        }.done {
            message.reply(.init(identifier: responseIdentifier, content: ["fired": true]))
        }.catch { err in
            Current.Log.error("Error during action event fire: \(err)")
            message.reply(.init(identifier: responseIdentifier, content: ["fired": false]))
        }
    }

    private func pushAction(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.pushActionResponse.rawValue

        if let infoJSON = message.content["PushActionInfo"] as? [String: Any],
           let info = Mapper<HomeAssistantAPI.PushActionInfo>().map(JSON: infoJSON),
           let serverIdentifier = message.content["Server"] as? String,
           let server = Current.servers.server(forServerIdentifier: serverIdentifier) {
            Current.backgroundTask(withName: "watch-push-action") { _ in
                firstly {
                    Current.api(for: server).handlePushAction(for: info)
                }.ensure {
                    message.reply(.init(identifier: responseIdentifier))
                }
            }.catch { error in
                Current.Log.error("error handling push action: \(error)")
            }
        }
    }

    private func sendMessage(message: ImmediateMessage) {
        Communicator.shared.send(message)
    }
}

// MARK: - Assist
extension WatchCommunicatorService {
    private func assistPipelinesFetch(message: InteractiveImmediateMessage) {
        let responseIdentifier = InteractiveImmediateResponses.assistPipelinesFetchResponse.rawValue

        let serverId = message.content["serverId"] as? String
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) ?? Current
            .servers.all.first else {
            Current.Log.warning("No server available to execute message \(message)")
            message.reply(.init(identifier: responseIdentifier, content: ["error": true]))
            return
        }

        firstly { () -> Promise<Void> in
            Promise { seal in
                initAssistServiceIfNeeded(server: server).fetchPipelines { pipelinesResponse in
                    if let pipelines = pipelinesResponse?.pipelines,
                       let preferredPipeline = pipelinesResponse?.preferredPipeline {
                        message.reply(.init(identifier: responseIdentifier, content: [
                            "pipelines": pipelines.map({ pipeline in
                                [
                                    "name": pipeline.name,
                                    "id": pipeline.id,
                                ]
                            }),
                            "preferredPipeline": preferredPipeline,
                        ]))
                        seal.fulfill(())
                    } else {
                        seal.reject(WatchAssistCommunicatorError.pipelinesFetchFailed)
                    }
                }
            }
        }.catch { err in
            Current.Log.error("Error during fetch Assist pipelines: \(err)")
            message.reply(.init(identifier: responseIdentifier, content: ["error": true]))
        }
    }

    private func assistAudioData(blob: Blob) {
        let responseIdentifier = InteractiveImmediateResponses.assistAudioDataResponse.rawValue

        let serverId = blob.metadata?["serverId"] as? String
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) ?? Current
            .servers.all.first else {
            let errorMessage = "No server available to execute message \(blob.identifier)"
            Current.Log.warning(errorMessage)
            return
        }

        firstly { [weak self] () -> Promise<Void> in
            Promise { seal in
                let pipelineId =  blob.metadata?["pipelineId"] as? String ?? ""
                guard let self, let sampleRate =  blob.metadata?["sampleRate"] as? Double else {
                    let errorMessage = "No sample rate received in message \(blob.identifier)"
                    Current.Log.error(errorMessage)
                    return
                }
                let audioData = blob.content
                self.pendingAudioData = audioData
                self.initAssistServiceIfNeeded(server: server).assist(source: .audio(
                    pipelineId: pipelineId,
                    audioSampleRate: sampleRate
                ))
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    seal.fulfill(())
                }
            }
        }.catch { err in
            let errorMessage = "Error during fetch Assist pipelines: \(err)"
            Current.Log.warning(errorMessage)
        }
    }

    private func initAssistServiceIfNeeded(server: Server) -> AssistServiceProtocol {
        if let assistService {
            assistService.replaceServer(server: server)
        } else {
            assistService = AssistService(server: server)
        }

        assistService?.delegate = self

        return assistService!
    }

    private func sendPendingAudioData() {
        if let pendingAudioData {
            assistService?.sendAudioData(pendingAudioData)
            /* 
             Since Apple watch sends the whole audio all at once, we can notify
             the pipeline that the audio data flow ended
             */
            assistService?.finishSendingAudio()
            self.pendingAudioData = nil
        }
    }
}
// MARK: - AssistServiceDelegate
extension WatchCommunicatorService: AssistServiceDelegate {
    func didReceiveEvent(_ event: Shared.AssistEvent) {
        Current.Log.info("Watch Assist received event: \(event)")
    }
    
    func didReceiveSttContent(_ content: String) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistSTTResponse.rawValue,
            content: [
                "content" : content
            ]
        )
        sendMessage(message: message)
    }
    
    func didReceiveIntentEndContent(_ content: String) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistIntentEndResponse.rawValue,
            content: [
                "content" : content
            ]
        )
        sendMessage(message: message)
    }
    
    func didReceiveGreenLightForAudioInput() {
        sendPendingAudioData()
    }
    
    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
        let message = ImmediateMessage(
            identifier: InteractiveImmediateResponses.assistTTSResponse.rawValue,
            content: [
                "mediaURL" : mediaUrl.absoluteString
            ]
        )
        sendMessage(message: message)
    }
}

// MARK: - ServerObserver
extension WatchCommunicatorService: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        _ = HomeAssistantAPI.SyncWatchContext()
    }
}
