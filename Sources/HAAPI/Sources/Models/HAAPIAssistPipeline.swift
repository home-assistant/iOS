/// One pipeline of an `assist_pipeline/pipeline/list` response.
public struct HAAPIAssistPipeline: Decodable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var language: String?

    enum CodingKeys: String, CodingKey {
        case id, name, language
    }
}
