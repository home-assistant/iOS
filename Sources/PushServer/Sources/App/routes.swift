import Vapor

func routes(_ app: Application) throws {
    app.group("push") { push in
        let pushController = PushController(appIdPrefix: Environment.get("APNS_TOPIC")!)
        push.post("send", use: pushController.send)
    }
}
