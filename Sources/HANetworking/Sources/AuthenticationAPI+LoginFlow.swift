import Alamofire
import Foundation

/// Home Assistant's login flow driven natively rather than through the web login page. The Apple Watch
/// uses it to sign in to a server on its own, so every watch holds its own refresh token instead of a
/// copy of the paired iPhone's.
///
/// Every call takes the base URL explicitly: the server refuses to continue a flow from a different IP
/// address than the one that started it, so a flow has to stay on the URL it was started on.
public extension AuthenticationAPI {
    func loginProviders(baseURL: URL) async throws -> [LoginFlowProvider] {
        try await session.request(baseURL.appendingPathComponent("auth/providers"))
            .validateAuth()
            .serializingDecodable(LoginFlowProviderList.self)
            .value
            .providers
    }

    func startLoginFlow(provider: LoginFlowProvider, baseURL: URL) async throws -> LoginFlowStep {
        // Most providers have no ID, which the server expects as an explicit `null`.
        let providerID: Any = provider.id.map { $0 as Any } ?? NSNull()
        let parameters: Parameters = [
            "client_id": AuthenticationRoute.clientID,
            "handler": [provider.type, providerID],
            "redirect_uri": AuthenticationRoute.redirectURI,
        ]
        return try await session.request(
            baseURL.appendingPathComponent("auth/login_flow"),
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .validateAuth()
        .serializingDecodable(LoginFlowStep.self)
        .value
    }

    /// Submit the user's input for the current form step. `input` maps field names to their values.
    func submitLoginFlow(flowID: String, input: [String: Any], baseURL: URL) async throws -> LoginFlowStep {
        var parameters: Parameters = input
        parameters["client_id"] = AuthenticationRoute.clientID
        return try await session.request(
            baseURL.appendingPathComponent("auth/login_flow").appendingPathComponent(flowID),
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .validateAuth()
        .serializingDecodable(LoginFlowStep.self)
        .value
    }

    /// Exchange the authorization code a finished login flow returned for a new token.
    func token(authorizationCode: String, baseURL: URL) async throws -> TokenInfo {
        let data = try await session.request(RouteInfo(
            route: .token(authorizationCode: authorizationCode),
            baseURL: baseURL
        ))
        .validateAuth()
        .serializingData()
        .value
        return try TokenInfo(JSONObject: JSONSerialization.jsonObject(with: data))
    }
}
