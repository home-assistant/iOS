import Foundation
import PromiseKit

public struct RateLimitResponse: Decodable {
    public var target: String

    public struct RateLimits: Decodable {
        public var attempts: Int
        public var successful: Int
        public var errors: Int
        public var total: Int
        public var maximum: Int
        public var remaining: Int
        public var resetsAt: Date
    }

    public var rateLimits: RateLimits
}

public class NotificationRateLimitsAPI {
    public class func rateLimits(pushID: String) -> Promise<RateLimitResponse> {
        firstly { () -> Promise<URLRequest> in
            do {
                var urlRequest = URLRequest(url: URL(
                    string: "https://mobile-apps.home-assistant.io/api/checkRateLimits"
                )!)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                    "push_token": pushID,
                ])
                return .value(urlRequest)
            } catch {
                return .init(error: error)
            }
        }.then {
            URLSession.shared.dataTask(.promise, with: $0)
        }.map { data, _ throws -> RateLimitResponse in
            let decoder = with(JSONDecoder()) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.sss'Z'"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                $0.dateDecodingStrategy = .formatted(dateFormatter)
            }
            return try decoder.decode(RateLimitResponse.self, from: data)
        }
    }
}
