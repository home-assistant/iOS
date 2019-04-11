//
//  HAAPI+WebSocket.swift
//  Shared
//
//  Created by Robert Trencheny on 4/9/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import PromiseKit
import Starscream

protocol WebsocketDelegate: AnyObject {
    func authSucceeded()
    func authFailed(_ message: String)
    func messageReceived(_ jsonString: String, _ respondingToType: String)
    func messageReceived(_ message: WebSocketMessage, _ respondingToType: String)
    func eventReceived(_ event: Event)
}

extension WebSocketDelegate {
    func authSucceeded() {}
    func authFailed(_ message: String) {}
    func messageReceived(_ jsonString: String, _ respondingToType: String) {}
    func messageReceived(_ message: WebSocketMessage, _ respondingToType: String) {}
    func eventReceived(_ event: Event) {}
}

extension HomeAssistantAPI: WebSocketDelegate {
    public func startWebsockets() {
        let baseWSURL = self.connectionInfo.activeAPIURL.appendingPathComponent("websocket")
        guard var components = URLComponents(url: baseWSURL, resolvingAgainstBaseURL: true) else {
            Current.Log.error("Unable to get components from base WS URL!")
            return
        }

        components.scheme = components.scheme == "http" ? "ws" : "wss"

        guard let wsURL = components.url else {
            Current.Log.error("Unable to build WS URL from components!")
            return
        }
        Current.Log.verbose("Connecting to WebSocket \(wsURL)")
        let socket = WebSocket(url: wsURL)
        self.socket = socket
        socket.delegate = self
        socket.connect()
    }

    public func authenticate() {
        _ = self.tokenManager?.bearerToken.done { token in
            _ = self.Send(AuthRequestMessage(accessToken: token))
        }
    }

    public func websocketDidConnect(socket: WebSocketClient) {
        Current.Log.verbose("WebSocket is connected")
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        self.socketAuthenticated = false
        HomeAssistantAPI.socketMessageCounter = 0
        if let error = error {
            Current.Log.error("WebSocket is disconnected with error \(error)")
            return
        }
        Current.Log.warning("WebSocket is disconnected")
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        Current.Log.verbose("Received WebSocket message: \(text)")
        if let message = self.DecodeMessage(text) {
            Current.Log.verbose("Decoded WS message: \(message.MessageType)")
            switch message.MessageType {
            case "auth_required":
                self.authenticate()
            case "auth_ok":
                self.socketAuthenticated = true
                self.socketDelegate?.authSucceeded()
            case "auth_invalid":
                self.socketAuthenticated = false
                self.socketDelegate?.authFailed(message.Message ?? "Unknown Error")
            case "result":
                var respondingTo = "Unknown"
                if let id = message.ID {
                    if let msgType = HomeAssistantAPI.socketMessageTypeMap[id] {
                        respondingTo = msgType
                    }
                    HomeAssistantAPI.socketMessages[id] = message
                    if let group = HomeAssistantAPI.socketDispatchGroups[id] {
                        group.leave()
                    }
                }
                self.socketDelegate?.messageReceived(message, respondingTo)
            case "event":
                self.socketDelegate?.eventReceived(Event(message.Result!))
            default:
                Current.Log.warning("Received unknown WebSocket command \(message.MessageType)")
            }
        }
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        Current.Log.verbose("WebSocket got some data: \(data.count)")
    }

    func EncodeWebSocketMessageToData(_ msg: WebSocketMessage) -> (Data, Int?)? {
        if msg.MessageType != "auth" {
            let id = HomeAssistantAPI.socketMessageCounter
            // Current.Log.verbose("Setting WS msg \(msg.MessageType) ID to \(id)")
            msg.ID = id
            HomeAssistantAPI.socketMessageTypeMap[id] = msg.MessageType
            HomeAssistantAPI.socketMessageCounter += 1
        }
        guard let encoded = try? JSONEncoder().encode(msg) else {
            return nil
        }
        return (encoded, msg.ID)
    }

    func EncodeWebSocketMessage(_ msg: WebSocketMessage) -> (String, Int?)? {
        guard let (encoded, id) = self.EncodeWebSocketMessageToData(msg),
            let str = String(data: encoded, encoding: .utf8) else { return nil }
        return (str, id)
    }

    func DecodeMessage(_ str: String) -> WebSocketMessage? {
        guard let jsonData = str.data(using: .utf8) else {
            Current.Log.error("Unable to convert incoming message JSON string to data")
            return nil
        }
        return try? JSONDecoder().decode(WebSocketMessage.self, from: jsonData)
    }

    func Send(_ msg: WebSocketMessage) -> (DispatchGroup?, Int?) {
        guard let (encoded, id) = self.EncodeWebSocketMessage(msg) else {
            Current.Log.error("Unable to encode \(msg.MessageType) message")
            return (nil, nil)
        }
        Current.Log.verbose("Sending WS msg: \(encoded)")
        var group: DispatchGroup?
        if let id = id {
            let newGroup = DispatchGroup()
            HomeAssistantAPI.socketDispatchGroups[id] = newGroup
            newGroup.enter()
            group = newGroup
        }
        self.socket?.write(string: encoded)
        return (group, id)
    }

    func Subscribe(_ eventType: String) -> (DispatchGroup?, Int?) {
        return self.Send(SubscribeEvents(eventType: eventType))
    }

    public func GetAuthenticatedUser() -> Promise<AuthenticatedUser?> {
        return Promise { seal in
            let (group, id) = self.Send(WebSocketMessage("auth/current_user"))
            group!.notify(queue: .main) {
                if let msg = HomeAssistantAPI.socketMessages[id!] {
                    seal.fulfill(AuthenticatedUser(msg.Result!))
                    return
                }
                seal.fulfill(nil)
            }
        }
    }

    // TODO: Implement get_themes support and subscribe to theme events.
}
