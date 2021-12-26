import APNS
import Vapor

public extension Request {
    var apns: APNSwiftClient {
        TestableAPNS(request: self)
    }

    struct TestableAPNS {
        let request: Request
    }
}

extension Request.TestableAPNS: APNSwiftClient {
    private var isTesting: Bool {
        request.application.environment == .testing
    }

    internal struct PendingSend {
        var promise: EventLoopPromise<Void>
        var payload: ByteBuffer
        var pushType: APNSwiftConnection.PushType
        var deviceToken: String
        var expiration: Date?
        var priority: Int?
        var collapseIdentifier: String?
        var topic: String?
        var apnsID: UUID?
    }

    static var pendingSendHandler: (PendingSend) -> Void = { _ in }

    public var logger: Logger? {
        request.logger
    }

    public var eventLoop: EventLoop {
        request.eventLoop
    }

    public func send(
        rawBytes payload: ByteBuffer,
        pushType: APNSwiftConnection.PushType,
        to deviceToken: String,
        expiration: Date?,
        priority: Int?,
        collapseIdentifier: String?,
        topic: String?,
        logger: Logger?,
        apnsID: UUID? = nil
    ) -> EventLoopFuture<Void> {
        if isTesting {
            let promise = request.eventLoop.makePromise(of: Void.self)
            Self.pendingSendHandler(.init(
                promise: promise,
                payload: payload,
                pushType: pushType,
                deviceToken: deviceToken,
                expiration: expiration,
                priority: priority,
                collapseIdentifier: collapseIdentifier,
                topic: topic,
                apnsID: apnsID
            ))
            return promise.futureResult
        } else {
            return request.application.apns.pool.withConnection(
                logger: logger,
                on: eventLoop
            ) {
                $0.send(
                    rawBytes: payload,
                    pushType: pushType,
                    to: deviceToken,
                    expiration: expiration,
                    priority: priority,
                    collapseIdentifier: collapseIdentifier,
                    topic: topic,
                    logger: logger,
                    apnsID: apnsID
                )
            }
        }
    }
}
