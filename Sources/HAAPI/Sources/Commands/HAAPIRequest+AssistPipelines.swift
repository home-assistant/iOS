public extension HAAPIRequest where Response == HAAPIAssistPipelineList {
    static func assistPipelineList() -> Self {
        .init(command: "assist_pipeline/pipeline/list")
    }
}
