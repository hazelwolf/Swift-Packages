import Foundation

public struct Note: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    /// Markdown text.
    public var body: String
    /// What the note belongs to in the host app, such as a topic or lesson id.
    public var anchor: String?
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        anchor: String? = nil,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.anchor = anchor
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isBlank: Bool {
        title.allSatisfy(\.isWhitespace) && body.allSatisfy(\.isWhitespace)
    }

    /// The targets of `[[wiki links]]` in the body, in order and without repeats.
    public var links: [String] {
        var seen = Set<String>()
        return body.matches(of: #/\[\[([^\[\]|]+)(?:\|[^\[\]]*)?\]\]/#).compactMap { match in
            let target = match.output.1.trimmingCharacters(in: .whitespaces)
            return !target.isEmpty && seen.insert(target).inserted ? target : nil
        }
    }

    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return title.range(of: query, options: options) != nil
            || body.range(of: query, options: options) != nil
            || tags.contains { $0.range(of: query, options: options) != nil }
    }
}
