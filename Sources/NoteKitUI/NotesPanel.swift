import NoteKit
import SwiftUI

public struct NotesPanelStyle: Sendable {
    public var text: Color
    public var secondaryText: Color
    public var fieldBackground: Color
    public var accent: Color
    public var fontDesign: Font.Design

    public init(
        text: Color = .primary,
        secondaryText: Color = .secondary,
        fieldBackground: Color = .secondary.opacity(0.1),
        accent: Color = .accentColor,
        fontDesign: Font.Design = .default
    ) {
        self.text = text
        self.secondaryText = secondaryText
        self.fieldBackground = fieldBackground
        self.accent = accent
        self.fontDesign = fontDesign
    }
}

/// A complete note editor for one anchor: note switcher, title, Markdown body and autosave.
public struct NotesPanel: View {
    @State private var model: NotesModel
    private let style: NotesPanelStyle

    public init(store: any NoteStore, anchor: String? = nil, style: NotesPanelStyle = NotesPanelStyle()) {
        _model = State(initialValue: NotesModel(store: store, anchor: anchor))
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbar
            if model.selected != nil {
                TextField("Title", text: binding(\.title))
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold, design: style.fontDesign))
                    .padding(10)
                    .background(style.fieldBackground, in: RoundedRectangle(cornerRadius: 8))
                TextEditor(text: binding(\.body))
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 16, design: style.fontDesign))
                    .lineSpacing(4)
                    .padding(8)
                    .frame(minHeight: 150)
                    .background(style.fieldBackground, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Note text")
            }
        }
        .foregroundStyle(style.text)
        .tint(style.accent)
        .task { await model.load() }
        .onDisappear {
            let model = model
            Task { await model.flush() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            if model.notes.count > 1 {
                Picker("Note", selection: $model.selectedID) {
                    ForEach(model.notes) { note in
                        Text(note.title.isEmpty ? "Untitled note" : note.title).tag(Optional(note.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }
            Text(statusText)
                .font(.system(size: 13, design: style.fontDesign))
                .foregroundStyle(style.secondaryText)
            Spacer()
            Button("New note", systemImage: "square.and.pencil") { model.newNote() }
            Button("Delete note", systemImage: "trash", role: .destructive) {
                Task { await model.deleteSelected() }
            }
            .labelStyle(.iconOnly)
            .disabled(model.selected?.isBlank ?? true)
        }
    }

    private var statusText: String {
        switch model.saveState {
        case .idle: ""
        case .saving: "Saving…"
        case .saved: "Saved"
        case .failed(let message): "Could not save: \(message)"
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Note, String>) -> Binding<String> {
        Binding {
            model.selected?[keyPath: keyPath] ?? ""
        } set: { value in
            model.editSelected { $0[keyPath: keyPath] = value }
        }
    }
}
