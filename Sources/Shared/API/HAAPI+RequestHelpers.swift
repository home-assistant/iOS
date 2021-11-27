import Alamofire
import Foundation
import ObjectMapper
import PromiseKit

extension HomeAssistantAPI {
    // MARK: - Helper methods for reducing boilerplate.

    func handleResponse<T>(response: AFDataResponse<T>, seal: Resolver<T>, callingFunctionName: String) {
        // Current.Log.verbose("\(callingFunctionName) response timeline: \(response.timeline)")
        switch response.result {
        case let .success(value):
            seal.fulfill(value)
        case let .failure(error):
            Current.Log.error("Error on \(callingFunctionName) request: \(error)")
            seal.reject(error)
        }
    }

    func request(
        path: String,
        callingFunctionName: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) -> Promise<String> {
        Promise { seal in
            let url = server.info.connection.activeAPIURL().appendingPathComponent(path)
            _ = manager.request(
                url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                headers: headers
            )
            .validate()
            .responseString { (response: AFDataResponse<String>) in
                self.handleResponse(
                    response: response,
                    seal: seal,
                    callingFunctionName: callingFunctionName
                )
            }
        }
    }

    func request<T: BaseMappable>(
        path: String,
        callingFunctionName: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) -> Promise<T> {
        Promise { seal in
            let url = server.info.connection.activeAPIURL().appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(
                        response: response,
                        seal: seal,
                        callingFunctionName: callingFunctionName
                    )
                }
        }
    }

    func request<T: BaseMappable>(
        path: String,
        callingFunctionName: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) -> Promise<[T]> {
        Promise { seal in
            let url = server.info.connection.activeAPIURL().appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseArray { (response: AFDataResponse<[T]>) in
                    self.handleResponse(
                        response: response,
                        seal: seal,
                        callingFunctionName: callingFunctionName
                    )
                }
        }
    }

    func request<T: ImmutableMappable>(
        path: String,
        callingFunctionName: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) -> Promise<T> {
        Promise { seal in
            let url = server.info.connection.activeAPIURL().appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(
                        response: response,
                        seal: seal,
                        callingFunctionName: callingFunctionName
                    )
                }
        }
    }

    func requestImmutable<T: ImmutableMappable>(
        path: String,
        callingFunctionName: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil
    ) -> Promise<T> {
        Promise { seal in
            let url = server.info.connection.activeAPIURL().appendingPathComponent(path)
            _ = manager.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
                .validate()
                .responseObject { (response: AFDataResponse<T>) in
                    self.handleResponse(
                        response: response,
                        seal: seal,
                        callingFunctionName: callingFunctionName
                    )
                }
        }
    }
}
