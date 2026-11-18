import Foundation
import LocalModelJobs
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Generates text on this device with MLX Swift, from weights already on disk.
public actor MLXTextBackend: TextGenerationBackend {
    private let location: LocalModelLocation
    private let enableThinking: Bool
    private var container: ModelContainer?
    private var conversations: [String: ChatSession] = [:]

    public init(location: LocalModelLocation, enableThinking: Bool = false) {
        self.location = location
        self.enableThinking = enableThinking
    }

    /// Loads the weights ahead of the first job.
    public func prepare() async throws {
        _ = try await loadedContainer()
    }

    public func generate(_ request: TextRequest) async throws -> AsyncThrowingStream<String, any Error> {
        let session = try await session(for: request)
        return session.streamResponse(to: request.prompt)
    }

    public func forgetConversation(_ id: String) {
        conversations[id] = nil
    }

    /// Frees the model's memory. It reloads on the next job.
    public func unload() {
        conversations.removeAll()
        container = nil
    }

    private func session(for request: TextRequest) async throws -> ChatSession {
        if let id = request.conversationID, let existing = conversations[id] { return existing }
        let session = ChatSession(
            try await loadedContainer(),
            instructions: request.instructions,
            generateParameters: GenerateParameters(
                maxTokens: request.maxTokens,
                temperature: Float(request.temperature)),
            additionalContext: ["enable_thinking": enableThinking])
        if let id = request.conversationID { conversations[id] = session }
        return session
    }

    private func loadedContainer() async throws -> ModelContainer {
        if let container { return container }
        let loaded = try await loadModelContainer(
            from: try location.resolve(),
            using: TransformersTokenizerLoader())
        container = loaded
        return loaded
    }
}

private struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(try await AutoTokenizer.from(modelFolder: directory))
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer, @unchecked Sendable {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}
