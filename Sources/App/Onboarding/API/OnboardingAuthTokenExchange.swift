import Shared

protocol OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: inout ConnectionInfo) async throws -> TokenInfo
}

class OnboardingAuthTokenExchangeImpl: OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: inout ConnectionInfo) async throws -> TokenInfo {
        try await TokenManager.initialToken(code: code, connectionInfo: &connectionInfo)
    }
}
