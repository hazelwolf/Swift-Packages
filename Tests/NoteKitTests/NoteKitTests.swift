import Foundation
import Testing
@testable import NoteKit

private let moment = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct NoteMarkdownCodecTests {
    @Test func roundTripsEveryField() throws {
        let note = Note(title: "Filters: \"edges\"", body: "# Heading\n\n---\n\nid: not front matter\n",
                        anchor: "topic:cnn", tags: ["vision", "maths"], createdAt: moment, updatedAt: moment)
        #expect(NoteMarkdownCodec.decode(try NoteMarkdownCodec.encode(note)) == note)
    }

    @Test func roundTripsANoteWithoutAnAnchor() throws {
        let note = Note(title: "Loose", body: "", createdAt: moment, updatedAt: moment)
        #expect(NoteMarkdownCodec.decode(try NoteMarkdownCodec.encode(note)) == note)
    }

    @Test func rejectsOrdinaryMarkdown() {
        #expect(NoteMarkdownCodec.decode("# Just a file\n") == nil)
    }
}

@Suite struct NoteTests {
    @Test func extractsUniqueWikiLinks() {
        let note = Note(body: "See [[Entropy]], [[ Gibbs | free energy ]] and [[Entropy]] again.")
        #expect(note.links == ["Entropy", "Gibbs"])
    }

    @Test func searchIgnoresCaseAndAccents() {
        #expect(Note(title: "Vidyopārjita").matches("vidyoparjita"))
        #expect(!Note(title: "Physics").matches("biology"))
    }
}

@Suite struct MarkdownNoteStoreTests {
    private func makeStore() -> MarkdownNoteStore {
        MarkdownNoteStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }

    @Test func emptyFolderHasNoNotes() async throws {
        #expect(try await makeStore().allNotes().isEmpty)
    }

    @Test func savesUpdatesAndDeletes() async throws {
        let store = makeStore()
        var note = Note(title: "First", createdAt: moment, updatedAt: moment)
        try await store.save(note)
        note.title = "Second"
        try await store.save(note)
        #expect(try await store.allNotes() == [note])
        try await store.delete(id: note.id)
        #expect(try await store.allNotes().isEmpty)
    }

    @Test func filtersByAnchorNewestFirst() async throws {
        let store = makeStore()
        let older = Note(title: "Older", anchor: "a", createdAt: moment, updatedAt: moment)
        let newer = Note(title: "Newer", anchor: "a", createdAt: moment, updatedAt: moment.addingTimeInterval(60))
        let other = Note(title: "Other", anchor: "b", createdAt: moment, updatedAt: moment)
        for note in [older, newer, other] { try await store.save(note) }
        #expect(try await store.notes(anchor: "a").map(\.title) == ["Newer", "Older"])
        #expect(try await store.search("other").map(\.title) == ["Other"])
    }
}
