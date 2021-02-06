import Alamofire
import Foundation
import UIKit

class MJPEGStreamerSessionDelegate: SessionDelegate {
    static var didReceiveResponse: Notification.Name = .init(rawValue: "MJPEGStreamerSessionDelegateDidReceiveResponse")
    static var taskUserInfoKey: AnyHashable = "taskUserInfoKey"

    // if/when alamofire also implements this again, we need to update to handle it as the breakpoint between images
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        NotificationCenter.default.post(
            name: Self.didReceiveResponse,
            object: self,
            userInfo: [Self.taskUserInfoKey: dataTask]
        )
        completionHandler(.allow)
    }
}

enum MJPEGEvent: CustomStringConvertible {
    case data(Data)
    case endOfResponse
    case endOfStream(AFError?)

    var description: String {
        switch self {
        case let .data(data):
            return "data(\(data.count))"
        case let .endOfStream(error):
            return "endOfStream(\(String(describing: error)))"
        case .endOfResponse:
            return "endOfResponse"
        }
    }
}

public class MJPEGStreamer {
    let manager: Alamofire.Session
    let queue = DispatchQueue(label: "mjpegstreamer-process")
    var data = Data()
    var request: DataStreamRequest?
    var callback: ((UIImage?, Error?) -> Void)?

    enum MJPEGError: Error {
        case unknownEndOfStream
    }

    init(manager: Alamofire.Session) {
        self.manager = manager

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveResponse(_:)),
            name: MJPEGStreamerSessionDelegate.didReceiveResponse,
            object: manager.delegate
        )
    }

    public func streamImages(fromURL url: URL, callback: @escaping (UIImage?, Error?) -> Void) {
        self.callback = callback

        request?.cancel()
        request = manager
            .streamRequest(url)
            .validate()
            .responseStream(on: queue, stream: { [weak self] stream in
                switch stream.event {
                case let .complete(completion):
                    self?.handle(event: .endOfStream(completion.error))
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        self?.handle(event: .data(data))
                    }
                }
            })
    }

    public var isActive: Bool {
        request != nil
    }

    public func cancel() {
        request?.cancel()
        request = nil
    }

    @objc private func didReceiveResponse(_ note: Notification) {
        queue.async { [self] in
            if note.userInfo?[MJPEGStreamerSessionDelegate.taskUserInfoKey] as? URLSessionTask == request?.task {
                handle(event: .endOfResponse)
            }
        }
    }

    private var pendingData = Data()
    private func handle(event: MJPEGEvent) {
        dispatchPrecondition(condition: .onQueue(queue))

        Current.Log.info(event)

        switch event {
        case let .data(data):
            pendingData.append(data)
        case let .endOfStream(error):
            DispatchQueue.main.async { [self] in
                callback?(nil, error ?? MJPEGError.unknownEndOfStream)
            }
        case .endOfResponse:
            let image = UIImage(data: pendingData)
            pendingData.removeAll(keepingCapacity: true)
            if let image = image {
                DispatchQueue.main.async { [self] in
                    callback?(image, nil)
                }
            }
        }
    }
}
