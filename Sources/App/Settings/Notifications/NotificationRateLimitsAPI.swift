import Eureka
import Foundation
import PromiseKit
import Shared

struct RateLimitResponse: Decodable {
    var target: String

    struct RateLimits: Decodable {
        var successful: Int
        var errors: Int
        var maximum: Int
        var remaining: Int
        var resetsAt: Date
    }

    var rateLimits: RateLimits
}

class NotificationRateLimitsAPI {
    class func rateLimits(pushID: String) -> Promise<RateLimitResponse> {
        firstly { () -> Promise<URLRequest> in
            do {
                var urlRequest = URLRequest(url: URL(
                    string: "https://haapns.fly.dev/rate_limits/check"
                )!)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
                    "push_token": pushID,
                ], options: [])
                return .value(urlRequest)
            } catch {
                return .init(error: error)
            }
        }.then {
            URLSession.shared.dataTask(.promise, with: $0)
        }.map { data, _ throws -> RateLimitResponse in
            let decoder = with(JSONDecoder()) {
                $0.dateDecodingStrategy = .iso8601
            }
            return try decoder.decode(RateLimitResponse.self, from: data)
        }
    }
}

extension RateLimitResponse.RateLimits {
    func row(for keyPath: KeyPath<Self, Int>) -> BaseRow {
        LabelRow {
            $0.value = NumberFormatter.localizedString(
                from: NSNumber(value: self[keyPath: keyPath]),
                number: .none
            )
            $0.title = { () -> String in
                switch keyPath {
                case \.successful:
                    return L10n.SettingsDetails.Notifications.RateLimits.delivered
                case \.errors:
                    return L10n.SettingsDetails.Notifications.RateLimits.errors
                case \.maximum:
                    return ""
                default:
                    fatalError("missing key: \(keyPath)")
                }
            }()
        }
    }

    func row(for keyPath: KeyPath<Self, Date>) -> BaseRow {
        LabelRow { row in
            row.value = DateFormatter.localizedString(
                from: self[keyPath: keyPath],
                dateStyle: .none,
                timeStyle: .medium
            )

            switch keyPath {
            case \.resetsAt:
                row.title = L10n.SettingsDetails.Notifications.RateLimits.resetsIn
                row.tag = "resetsIn"
            default:
                fatalError("missing key: \(keyPath)")
            }
        }
    }
}
