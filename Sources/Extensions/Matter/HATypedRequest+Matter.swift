import HAKit

extension HATypedRequest {
    static func matterComissionOnNetwork(
        pin: Int
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "matter/commission_on_network",
            data: ["pin": pin]
        ))
    }
}
