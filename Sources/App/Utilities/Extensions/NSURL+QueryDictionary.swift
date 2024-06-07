import Foundation

extension URL {
    var queryItems: [String: String]? {
        var params = [String: String]()
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce([:], { _, item -> [String: String] in
                params[item.name] = item.value
                return params
            })
    }
}
