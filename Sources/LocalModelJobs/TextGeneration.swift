import Foundation

/// One text generation to run on a local model.
public struct TextRequest: Sendable, Hashable {
    public var prompt: String
    public var instructions: String?
    /// Requests that share an id continue the same conversation. `nil` starts a fresh one.
    public var conversationID: String?
    public var maxTokens: Int
    public var temperature: Double

    public init(
        prompt: String,
        instructions: String? = nil,
        conversationID: String? = nil,
        maxTokens: Int = 500,
        temperature: Double = 0.6
    ) {
        self.prompt = prompt
        self.instructions = instructions
        self.conversationID = conversationID
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

/// A local model runtime. Conform to this to run jobs on MLX, or on a fake in tests.
public protocol TextGenerationBackend: Sendable {
    func generate(_ request: TextRequest) async throws -> AsyncThrowingStream<String, any Error>
}
