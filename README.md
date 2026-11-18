# Swift-Packages

Reusable Swift libraries for macOS 15+ and iOS 18+.

| Library | What it does |
|---|---|
| `LocalModelJobs` | Runs local text generation jobs one at a time, with streaming, cancellation and model lookup. It has no MLX dependency. |
| `LocalModelMLX` | Runs those jobs on Apple Silicon with MLX Swift, from weights already on disk. |
| `NoteKit` | Stores notes as readable Markdown files, with anchors, tags, wiki links and search. |
| `NoteKitUI` | A ready-made SwiftUI note editor with autosave. |

## Add to a package

```swift
dependencies: [
    .package(url: "https://github.com/hazelwolf/Swift-Packages.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyFeature", dependencies: [
        .product(name: "NoteKit", package: "Swift-Packages"),
        .product(name: "LocalModelMLX", package: "Swift-Packages"),
    ]),
]
```

In Xcode, choose **File > Add Package Dependencies** and enter the repository URL.

## Run a local model job

```swift
import LocalModelJobs
import LocalModelMLX

let queue = ModelJobQueue(backend: MLXTextBackend(
    location: .huggingFaceCache(repo: "mlx-community/Qwen3-8B-4bit")))

let job = await queue.submit(TextRequest(prompt: "Explain entropy simply."))
for await event in job.events {
    if case .text(let text) = event { print(text, terminator: "") }
}
```

## Add notes to a screen

```swift
import NoteKit
import NoteKitUI

let store = MarkdownNoteStore(directory: URL.applicationSupportDirectory.appending(path: "Notes"))

NotesPanel(store: store, anchor: "lesson:42")
```

## Build requirements

Building `LocalModelMLX` needs Xcode's Metal Toolchain:

```bash
xcodebuild -downloadComponent MetalToolchain
```
