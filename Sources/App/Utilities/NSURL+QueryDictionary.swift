import Foundation
extension URL {
    var queryDictionary: [String: [String]]? {
        if let query = query {
            var dictionary = [String: [String]]()

            for keyValueString in query.components(separatedBy: "&") {
                let parts = keyValueString.components(separatedBy: "=")
                if parts.count < 2 { continue }

                let key = parts[0].removingPercentEncoding!
                let value = parts[1].removingPercentEncoding!

                var values = dictionary[key] ?? [String]()
                values.append(value)
                dictionary[key] = values
            }

            return dictionary
        }

        return nil
    }

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
