//
//  MjpegStreamingController.swift
//  HomeAssistant
//
//  Created by Stefano Vettor on 28/03/16.
//  Updated by Robbie Trencheny on 15/09/16.
//  Copyright © 2016 Stefano Vettor. All rights reserved.
//

import UIKit

open class MjpegStreamingController: NSObject, URLSessionDataDelegate {

    fileprivate enum Status {
        case stopped
        case loading
        case playing
    }

    fileprivate var receivedData: NSMutableData?
    fileprivate var dataTask: URLSessionDataTask?
    fileprivate var session: Foundation.URLSession!
    fileprivate var status: Status = .stopped

    open var authenticationHandler: ((URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
    open var didStartLoading: (() -> Void)?
    open var didFinishLoading: (() -> Void)?
    open var contentURL: URL?
    open var imageView: UIImageView

    public init(imageView: UIImageView, sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.imageView = imageView
        super.init()
        self.session = Foundation.URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }

    public convenience init(imageView: UIImageView, contentURL: URL, sessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.init(imageView: imageView, sessionConfiguration: sessionConfiguration)
        self.contentURL = contentURL
    }

    deinit {
        dataTask?.cancel()
    }

    open func play(url: URL) {
        if status == .playing || status == .loading {
            stop()
        }
        contentURL = url
        play()
    }

    open func play() {
        guard let url = contentURL, status == .stopped else {
            return
        }

        status = .loading
        DispatchQueue.main.async { self.didStartLoading?() }

        receivedData = NSMutableData()
        let request = URLRequest(url: url)
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }

    open func stop() {
        status = .stopped
        dataTask?.cancel()
    }

    // MARK: - NSURLSessionDataDelegate

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let imageData = receivedData, imageData.length > 0,
            let receivedImage = UIImage(data: imageData as Data) {
            // I'm creating the UIImage before performing didFinishLoading to minimize the interval
            // between the actions done by didFinishLoading and the appearance of the first image
            if status == .loading {
                status = .playing
                DispatchQueue.main.async { self.didFinishLoading?() }
            }

            DispatchQueue.main.async { self.imageView.image = receivedImage }
        }

        receivedData = NSMutableData()
        completionHandler(.allow)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
    }

    // MARK: - NSURLSessionTaskDelegate

    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        var credential: URLCredential?
        var disposition: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling

        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                credential = URLCredential(trust: trust)
                disposition = .useCredential
            }
        } else if let onAuthentication = authenticationHandler {
            (disposition, credential) = onAuthentication(challenge)
        }

        completionHandler(disposition, credential)
    }
}
