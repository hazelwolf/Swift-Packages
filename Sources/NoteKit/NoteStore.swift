import Foundation

public protocol NoteStore: Sendable {
    /// Every note, most recently updated first.
    func allNotes() async throws -> [Note]
    func save(_ note: Note) async throws
    func delete(id: Note.ID) async throws
}

extension NoteStore {
    public func notes(anchor: String) async throws -> [Note] {
        try await allNotes().filter { $0.anchor == anchor }
    }

    public func search(_ query: String) async throws -> [Note] {
        try await allNotes().filter { $0.matches(query) }
    }
}

/// Keeps each note as a readable `.md` file in one folder.
public actor MarkdownNoteStore: NoteStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func allNotes() throws -> [Note] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: directory.path) else { return [] }
        return try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .compactMap { url in
                (try? String(contentsOf: url, encoding: .utf8)).flatMap(NoteMarkdownCodec.decode)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(_ note: Note) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try NoteMarkdownCodec.encode(note).write(to: file(for: note.id), atomically: true, encoding: .utf8)
    }

    public func delete(id: Note.ID) throws {
        let url = file(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func file(for id: Note.ID) -> URL {
        directory.appending(path: "\(id.uuidString).md")
    }
}
