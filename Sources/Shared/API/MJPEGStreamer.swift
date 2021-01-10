import Foundation
import UIKit
import Alamofire

class ImageStreamSerializer: DataStreamSerializer {
    func serialize(_ data: Data) throws -> UIImage? {
        if let image = UIImage(data: data) {
            return image
        } else {
            return nil
        }
    }
}

public class MJPEGStreamer {
    let manager: Alamofire.Session
    var data: Data = Data()
    var request: DataStreamRequest?
    var callback: ((UIImage?, Error?) -> Void)?

    init(manager: Alamofire.Session) {
        self.manager = manager
    }

    public func streamImages(fromURL url: URL, callback: @escaping (UIImage?, Error?) -> Void) {
        self.callback = callback

        self.request?.cancel()
        self.request = self.manager.streamRequest(url).responseStream(using: ImageStreamSerializer()) { result in
            switch result.result ?? .success(nil) {
            case .success(let image):
                if let image = image {
                    callback(image, nil)
                }
            case .failure(let error):
                callback(nil, error)
            }
        }
    }

    public var isActive: Bool {
        return self.request != nil
    }
    public func cancel() {
        self.request?.cancel()
        self.request = nil
    }
}
