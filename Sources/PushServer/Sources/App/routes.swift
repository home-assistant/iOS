import Vapor

func routes(_ app: Application) throws {
    app.group("push") { push in
        let pushTopic = Environment.get("APNS_TOPIC") ?? "io.robbie.HomeAssistant"
        let pushController = PushController(appIdPrefix: pushTopic)

        push.post("send") { req in
            try await pushController.send(req: req)
        }
    }
}
