import HAKit

extension HATypedRequest {
    static func matterComission(
        code: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "matter/commission",
            data: ["code": code]
        ))
    }
}
