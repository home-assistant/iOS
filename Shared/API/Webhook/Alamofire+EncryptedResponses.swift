//
//  Alamofire+EncryptedResponses.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 3/7/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation
import Alamofire
import ObjectMapper
import Sodium

// swiftlint:disable line_length
extension DataRequest {

    /// A replacement JSON Serializer for Alamofire that has support for responses that are encrypted via Sodium.
    public static func serializeResponseEncryptedJSON(options: JSONSerialization.ReadingOptions,
                                                      response: HTTPURLResponse?,
                                                      data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }

        if let response = response, [204, 205].contains(response.statusCode) { return .success(NSNull()) }

        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        do {
            let json = try JSONSerialization.jsonObject(with: validData, options: options)

            if let obj = json as? [String: Any], let encryptedData = obj["encrypted_data"] as? String,
                let secret = Current.settingsStore.webhookSecret {

                let sodium = Sodium()

                guard let decoded = sodium.utils.base642bin(encryptedData, variant: .ORIGINAL, ignore: nil) else {
                    return .failure(newError(.dataSerializationFailed,
                                             failureReason: "Error decoding from base64 to bytes!"))
                }

                guard let decrypted = sodium.secretBox.open(nonceAndAuthenticatedCipherText: decoded,
                                                            secretKey: secret.bytes) else {
                    return .failure(newError(.dataSerializationFailed,
                                             failureReason: "Error when decrypting webhook response!"))
                }

                return .success(try JSONSerialization.jsonObject(with: Data(bytes: decrypted), options: options))
            }
            return .success(json)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error)))
        }
    }

    public static func encryptedJSONResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<Any> {
        return DataResponseSerializer { _, response, data, error in
            return DataRequest.serializeResponseEncryptedJSON(options: options, response: response, data: data, error: error)
        }
    }

    @discardableResult
    public func responseEncryptedJSON(queue: DispatchQueue? = nil,
                                      options: JSONSerialization.ReadingOptions = .allowFragments,
                                      completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
        return response(
            queue: queue,
            responseSerializer: DataRequest.encryptedJSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }

    // Everything after this point comes directly from AlamofireObjectMapper.
    // It's here so that we use the encrypted JSON serializer.
    // https://github.com/tristanhimmelman/AlamofireObjectMapper/blob/5.2.0/AlamofireObjectMapper/AlamofireObjectMapper.swift
    enum ErrorCode: Int {
        case noData = 1
        case dataSerializationFailed = 2
    }

    internal static func newError(_ code: ErrorCode, failureReason: String) -> NSError {
        let errorDomain = "com.alamofireobjectmapper.error"

        let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
        let returnError = NSError(domain: errorDomain, code: code.rawValue, userInfo: userInfo)

        return returnError
    }

    /// Utility function for checking for errors in response
    internal static func checkResponseForError(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Error? {
        if let error = error {
            return error
        }
        guard data != nil else {
            let failureReason = "Data could not be serialized. Input data was nil."
            let error = newError(.noData, failureReason: failureReason)
            return error
        }
        return nil
    }

    /// Utility function for extracting JSON from response
    internal static func processResponse(request: URLRequest?, response: HTTPURLResponse?, data: Data?, keyPath: String?) -> Any? {
        let encryptedJSONResponseSerializer = DataRequest.encryptedJSONResponseSerializer(options: .allowFragments)
        let result = encryptedJSONResponseSerializer.serializeResponse(request, response, data, nil)

        let JSON: Any?
        if let keyPath = keyPath, keyPath.isEmpty == false {
            JSON = (result.value as AnyObject?)?.value(forKeyPath: keyPath)
        } else {
            JSON = result.value
        }

        return JSON
    }

    /// BaseMappable Object Serializer
    public static func ObjectMapperSerializer<T: BaseMappable>(_ keyPath: String?, mapToObject object: T? = nil, context: MapContext? = nil) -> DataResponseSerializer<T> {
        return DataResponseSerializer { request, response, data, error in
            if let error = checkResponseForError(request: request, response: response, data: data, error: error) {
                return .failure(error)
            }

            let JSONObject = processResponse(request: request, response: response, data: data, keyPath: keyPath)

            if let object = object {
                _ = Mapper<T>(context: context, shouldIncludeNilValues: false).map(JSONObject: JSONObject, toObject: object)
                return .success(object)
            } else if let parsedObject = Mapper<T>(context: context, shouldIncludeNilValues: false).map(JSONObject: JSONObject) {
                return .success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = newError(.dataSerializationFailed, failureReason: failureReason)
            return .failure(error)
        }
    }

    /// ImmutableMappable Array Serializer
    public static func ObjectMapperImmutableSerializer<T: ImmutableMappable>(_ keyPath: String?, context: MapContext? = nil) -> DataResponseSerializer<T> {
        return DataResponseSerializer { request, response, data, error in
            if let error = checkResponseForError(request: request, response: response, data: data, error: error) {
                return .failure(error)
            }

            let JSONObject = processResponse(request: request, response: response, data: data, keyPath: keyPath)

            if let JSONObject = JSONObject,
                let parsedObject = (try? Mapper<T>(context: context, shouldIncludeNilValues: false).map(JSONObject: JSONObject)) {
                return .success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = newError(.dataSerializationFailed, failureReason: failureReason)
            return .failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished.

     - parameter queue:             The queue on which the completion handler is dispatched.
     - parameter keyPath:           The key path where object mapping should be performed
     - parameter object:            An object to perform the mapping on to
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    @discardableResult
    public func responseObject<T: BaseMappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, mapToObject object: T? = nil, context: MapContext? = nil, completionHandler: @escaping (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.ObjectMapperSerializer(keyPath, mapToObject: object, context: context), completionHandler: completionHandler)
    }

    @discardableResult
    public func responseObject<T: ImmutableMappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, mapToObject object: T? = nil, context: MapContext? = nil, completionHandler: @escaping (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.ObjectMapperImmutableSerializer(keyPath, context: context), completionHandler: completionHandler)
    }

    /// BaseMappable Array Serializer
    public static func ObjectMapperArraySerializer<T: BaseMappable>(_ keyPath: String?, context: MapContext? = nil) -> DataResponseSerializer<[T]> {
        return DataResponseSerializer { request, response, data, error in
            if let error = checkResponseForError(request: request, response: response, data: data, error: error) {
                return .failure(error)
            }

            let JSONObject = processResponse(request: request, response: response, data: data, keyPath: keyPath)

            if let parsedObject = Mapper<T>(context: context, shouldIncludeNilValues: false).mapArray(JSONObject: JSONObject) {
                return .success(parsedObject)
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = newError(.dataSerializationFailed, failureReason: failureReason)
            return .failure(error)
        }
    }

    /// ImmutableMappable Array Serializer
    public static func ObjectMapperImmutableArraySerializer<T: ImmutableMappable>(_ keyPath: String?, context: MapContext? = nil) -> DataResponseSerializer<[T]> {
        return DataResponseSerializer { request, response, data, error in
            if let error = checkResponseForError(request: request, response: response, data: data, error: error) {
                return .failure(error)
            }

            if let JSONObject = processResponse(request: request, response: response, data: data, keyPath: keyPath) {

                if let parsedObject = try? Mapper<T>(context: context, shouldIncludeNilValues: false).mapArray(JSONObject: JSONObject) {
                    return .success(parsedObject)
                }
            }

            let failureReason = "ObjectMapper failed to serialize response."
            let error = newError(.dataSerializationFailed, failureReason: failureReason)
            return .failure(error)
        }
    }

    /**
     Adds a handler to be called once the request has finished. T: BaseMappable

     - parameter queue: The queue on which the completion handler is dispatched.
     - parameter keyPath: The key path where object mapping should be performed
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    @discardableResult
    public func responseArray<T: BaseMappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, context: MapContext? = nil, completionHandler: @escaping (DataResponse<[T]>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.ObjectMapperArraySerializer(keyPath, context: context), completionHandler: completionHandler)
    }

    /**
     Adds a handler to be called once the request has finished. T: ImmutableMappable

     - parameter queue: The queue on which the completion handler is dispatched.
     - parameter keyPath: The key path where object mapping should be performed
     - parameter completionHandler: A closure to be executed once the request has finished and the data has been mapped by ObjectMapper.

     - returns: The request.
     */
    @discardableResult
    public func responseArray<T: ImmutableMappable>(queue: DispatchQueue? = nil, keyPath: String? = nil, context: MapContext? = nil, completionHandler: @escaping (DataResponse<[T]>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.ObjectMapperImmutableArraySerializer(keyPath, context: context), completionHandler: completionHandler)
    }
}
