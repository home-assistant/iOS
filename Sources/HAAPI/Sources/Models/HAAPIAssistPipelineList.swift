/// The full `assist_pipeline/pipeline/list` response.
public struct HAAPIAssistPipelineList: Decodable, Sendable, Equatable {
    public var pipelines: [HAAPIAssistPipeline]
    public var preferredPipeline: String?

    enum CodingKeys: String, CodingKey {
        case pipelines
        case preferredPipeline = "preferred_pipeline"
    }
}
