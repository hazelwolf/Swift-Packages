/// Removes `<think>…</think>` blocks from streamed text, including tags split across chunks,
/// and drops the whitespace that models emit before their first visible word.
public struct ThinkFilter: Sendable {
    private var buffer = ""
    private var thinking = false
    private var hasEmitted = false

    public init() {}

    public mutating func consume(_ chunk: String) -> String {
        buffer += chunk
        var output = ""
        while true {
            let tag = thinking ? "</think>" : "<think>"
            if let range = buffer.range(of: tag) {
                if !thinking { output += buffer[..<range.lowerBound] }
                buffer = String(buffer[range.upperBound...])
                thinking.toggle()
                continue
            }
            let held = (1..<tag.count).reversed().first { buffer.hasSuffix(tag.prefix($0)) } ?? 0
            let cut = buffer.index(buffer.endIndex, offsetBy: -held)
            if !thinking { output += buffer[..<cut] }
            buffer = String(buffer[cut...])
            return visible(output)
        }
    }

    /// Returns text held back as a possible tag once the stream has ended.
    public mutating func finish() -> String {
        defer { buffer = "" }
        return thinking ? "" : visible(buffer)
    }

    private mutating func visible(_ text: String) -> String {
        guard !hasEmitted else { return text }
        let trimmed = String(text.drop(while: \.isWhitespace))
        hasEmitted = !trimmed.isEmpty
        return trimmed
    }
}
