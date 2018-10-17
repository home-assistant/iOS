import Foundation
import Alamofire

public class MJPEGStreamer {
    let manager: Alamofire.SessionManager
    var data: Data = Data()
    var request: DataRequest?
    var callback: ((UIImage?, Error?) -> Void)?

    init(manager: Alamofire.SessionManager) {
        self.manager = manager
        manager.delegate.dataTaskDidReceiveResponse = { [weak self] session, task, response ->
            URLSession.ResponseDisposition in
            guard let this = self else {
                return .cancel
            }

            if let requestURL = this.request?.request?.url, response.url == requestURL {
                let image = UIImage(data: this.data)
                this.data = Data()
                if let unwrappedImage = image {
                    DispatchQueue.main.async {
                        this.callback?(unwrappedImage, nil)
                    }
                }

                return .allow
            }

            return .cancel
        }
    }

    public func streamImages(fromURL url: URL, callback: @escaping (UIImage?, Error?) -> Void) {
        self.callback = callback
        self.request?.cancel()
        self.request = self.manager.request(url).validate()
            .response(completionHandler: { (response) in
                if let error = response.error {
                    callback(nil, error)
                }
            })
        self.request?.resume()

        request?.stream { [weak self] buffer in
            guard let this = self else {
                return
            }

            this.data.append(buffer)
        }
    }

    public func cancel() {
        self.request?.cancel()
    }
}
