import PromiseKit
import Shared

protocol OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: ConnectionInfo) -> Promise<TokenInfo>
}

class OnboardingAuthTokenExchangeImpl: OnboardingAuthTokenExchange {
    func tokenInfo(code: String, connectionInfo: ConnectionInfo) -> Promise<TokenInfo> {
        let tokenManager = TokenManager(tokenInfo: nil, forcedConnectionInfo: connectionInfo)
        return tokenManager.initialTokenWithCode(code).ensure {
            withExtendedLifetime(tokenManager) {
                // preserving it until it's done
            }
        }
    }
}
