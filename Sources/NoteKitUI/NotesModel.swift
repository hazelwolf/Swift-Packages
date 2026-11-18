import Foundation
import NoteKit
import Observation

/// Editing state for the notes attached to one anchor. Changes save automatically.
@MainActor
@Observable
public final class NotesModel {
    public enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    public private(set) var notes: [Note] = []
    public var selectedID: Note.ID?
    public private(set) var saveState = SaveState.idle

    private let store: any NoteStore
    private let anchor: String?
    private var dirty = Set<Note.ID>()
    private var saveTask: Task<Void, Never>?

    public init(store: any NoteStore, anchor: String? = nil) {
        self.store = store
        self.anchor = anchor
    }

    public var selected: Note? {
        notes.first { $0.id == selectedID }
    }

    public func load() async {
        do {
            notes = if let anchor {
                try await store.notes(anchor: anchor)
            } else {
                try await store.allNotes()
            }
            if notes.isEmpty { newNote() } else { selectedID = notes[0].id }
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    public func newNote() {
        let note = Note(anchor: anchor)
        notes.insert(note, at: 0)
        selectedID = note.id
    }

    public func editSelected(_ change: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&notes[index])
        notes[index].updatedAt = .now
        dirty.insert(notes[index].id)
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    public func deleteSelected() async {
        guard let id = selectedID else { return }
        dirty.remove(id)
        do {
            try await store.delete(id: id)
            notes.removeAll { $0.id == id }
            if notes.isEmpty { newNote() } else { selectedID = notes[0].id }
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    /// Writes pending edits now. Notes with no words yet are not saved.
    public func flush() async {
        saveTask?.cancel()
        let pending = notes.filter { dirty.contains($0.id) && !$0.isBlank }
        guard !pending.isEmpty else { return }
        saveState = .saving
        do {
            for note in pending {
                try await store.save(note)
                if notes.first(where: { $0.id == note.id }) == note { dirty.remove(note.id) }
            }
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }
}
