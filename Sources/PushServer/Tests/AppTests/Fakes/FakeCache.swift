import Vapor

final class FakeCache: Cache {
    var values = [String: Any]()
    var expirations = [String: CacheExpirationTime]()
    let eventLoop: EventLoop

    init(values: [String: Any] = [:], eventLoop: EventLoop) {
        self.values = values
        self.eventLoop = eventLoop
    }

    func get<T>(_ key: String, as type: T.Type) -> EventLoopFuture<T?> where T: Decodable {
        eventLoop.makeSucceededFuture(values[key] as? T)
    }

    func set<T>(_ key: String, to value: T?) -> EventLoopFuture<Void> where T: Encodable {
        set(key, to: value, expiresIn: nil)
    }

    func set<T>(_ key: String, to value: T?, expiresIn expirationTime: CacheExpirationTime?) -> EventLoopFuture<Void>
        where T: Encodable {
        values[key] = value
        expirations[key] = value != nil ? expirationTime : nil
        return eventLoop.makeSucceededFuture(())
    }

    func `for`(_ request: Request) -> Self {
        .init(values: values, eventLoop: eventLoop)
    }
}
