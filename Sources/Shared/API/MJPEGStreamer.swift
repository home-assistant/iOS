import Foundation
import UIKit
import Alamofire

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
        case .data(let data):
            return "data(\(data.count))"
        case .endOfStream(let error):
            return "endOfStream(\(String(describing: error)))"
        case .endOfResponse:
            return "endOfResponse"
        }
    }
}

public class MJPEGStreamer {
    let manager: Alamofire.Session
    let queue = DispatchQueue(label: "mjpegstreamer-process")
    var data: Data = Data()
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

        self.request?.cancel()
        self.request = self.manager
            .streamRequest(url)
            .validate()
            .responseStream(on: queue, stream: { [weak self] stream in
                switch stream.event {
                case .complete(let completion):
                    self?.handle(event: .endOfStream(completion.error))
                case .stream(let result):
                    switch result {
                    case .success(let data):
                        self?.handle(event: .data(data))
                    }
                }
            })
    }

    public var isActive: Bool {
        return self.request != nil
    }
    public func cancel() {
        self.request?.cancel()
        self.request = nil
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
        case .data(let data):
            pendingData.append(data)
        case .endOfStream(let error):
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
