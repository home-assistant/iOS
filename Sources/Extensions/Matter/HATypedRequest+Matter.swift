import HAKit
import Shared

extension HATypedRequest {
    static func matterCommission(
        code: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "matter/commission",
            data: ["code": code]
        ))
    }
}
