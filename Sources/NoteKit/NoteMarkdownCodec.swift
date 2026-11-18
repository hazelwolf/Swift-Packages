import Foundation

/// Reads and writes a note as a Markdown file with a small front matter block.
public enum NoteMarkdownCodec {
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    public static func encode(_ note: Note) throws -> String {
        let header = [
            "---",
            "id: \(note.id.uuidString)",
            "title: \(try json(note.title))",
            "anchor: \(try json(note.anchor))",
            "tags: \(try json(note.tags))",
            "created: \(note.createdAt.formatted(dateStyle))",
            "updated: \(note.updatedAt.formatted(dateStyle))",
            "---",
            "",
        ]
        return header.joined(separator: "\n") + note.body
    }

    /// Returns `nil` when the text is not a note written by `encode`.
    public static func decode(_ text: String) -> Note? {
        guard text.hasPrefix("---\n"),
              let end = text.range(of: "\n---\n", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex)
        else { return nil }

        let fields = text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound]
            .split(separator: "\n")
            .reduce(into: [String: String]()) { result, line in
                guard let colon = line.range(of: ": ") else { return }
                result[String(line[..<colon.lowerBound])] = String(line[colon.upperBound...])
            }

        guard let id = fields["id"].flatMap(UUID.init(uuidString:)),
              let title = fields["title"].flatMap({ value(String.self, $0) }),
              let anchor = fields["anchor"].flatMap({ value(String?.self, $0) }),
              let tags = fields["tags"].flatMap({ value([String].self, $0) }),
              let created = fields["created"].flatMap({ try? dateStyle.parse($0) }),
              let updated = fields["updated"].flatMap({ try? dateStyle.parse($0) })
        else { return nil }

        return Note(id: id, title: title, body: String(text[end.upperBound...]), anchor: anchor,
                    tags: tags, createdAt: created, updatedAt: updated)
    }

    private static func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private static func value<T: Decodable>(_ type: T.Type, _ text: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(text.utf8))
    }
}
