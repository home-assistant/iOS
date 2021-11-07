import PromiseKit
import Shared

protocol OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: ConnectionInfo) -> Promise<TokenInfo>
}

class OnboardingAuthTokenExchangeImpl: OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: ConnectionInfo) -> Promise<TokenInfo> {
        TokenManager.initialToken(code: code, connectionInfo: connectionInfo)
    }
}
