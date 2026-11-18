import Foundation
import Testing
@testable import LocalModelJobs

private struct ScriptedBackend: TextGenerationBackend {
    struct Boom: LocalizedError { var errorDescription: String? { "boom" } }
    var chunks = ["Hello ", "world"]
    var fails = false
    var delay: Duration = .zero

    func generate(_ request: TextRequest) async throws -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for chunk in chunks {
                        try await Task.sleep(for: delay)
                        continuation.yield(request.prompt + ":" + chunk)
                    }
                    continuation.finish(throwing: fails ? Boom() : nil)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private func collect(_ job: ModelJob) async -> [ModelJobEvent] {
    var events: [ModelJobEvent] = []
    for await event in job.events { events.append(event) }
    return events
}

@Suite struct ThinkFilterTests {
    @Test func removesThinkingSplitAcrossChunks() {
        var filter = ThinkFilter()
        let output = ["<thi", "nk>secret</th", "ink>\n\nHel", "lo"].map { filter.consume($0) }.joined()
        #expect(output + filter.finish() == "Hello")
    }

    @Test func keepsTextThatOnlyLooksLikeATag() {
        var filter = ThinkFilter()
        let output = filter.consume("a <thi")
        #expect(output + filter.finish() == "a <thi")
    }

    @Test func dropsUnfinishedThinking() {
        var filter = ThinkFilter()
        let output = filter.consume("<think>never closed")
        #expect(output + filter.finish() == "")
    }
}

@Suite struct ModelJobQueueTests {
    @Test func streamsThenFinishes() async {
        let queue = ModelJobQueue(backend: ScriptedBackend(chunks: ["a", "b"]))
        let events = await collect(queue.submit(TextRequest(prompt: "p")))
        #expect(events == [.queued, .started, .text("p:a"), .text("p:b"), .finished("p:ap:b")])
    }

    @Test func reportsFailureAndKeepsWorking() async {
        let failing = ModelJobQueue(backend: ScriptedBackend(chunks: [], fails: true))
        let first = await collect(failing.submit(TextRequest(prompt: "p")))
        let second = await collect(failing.submit(TextRequest(prompt: "p")))
        #expect(first.last == .failed("boom"))
        #expect(second.last == .failed("boom"))
    }

    @Test func runsJobsOneAtATimeInOrder() async {
        let queue = ModelJobQueue(backend: ScriptedBackend(chunks: ["x"], delay: .milliseconds(20)))
        let first = await queue.submit(TextRequest(prompt: "1"))
        let second = await queue.submit(TextRequest(prompt: "2"))
        let firstEvents = await collect(first)
        let secondEvents = await collect(second)
        #expect(firstEvents.last == .finished("1:x"))
        #expect(secondEvents.last == .finished("2:x"))
    }

    @Test func cancelsAQueuedJobWithoutRunningIt() async {
        let queue = ModelJobQueue(backend: ScriptedBackend(chunks: ["x"], delay: .milliseconds(100)))
        let running = await queue.submit(TextRequest(prompt: "1"))
        let waiting = await queue.submit(TextRequest(prompt: "2"))
        await queue.cancel(waiting.id)
        #expect(await collect(waiting) == [.queued, .cancelled("")])
        #expect(await collect(running).last == .finished("1:x"))
    }

    @Test func cancelsTheRunningJob() async {
        let queue = ModelJobQueue(backend: ScriptedBackend(chunks: ["x", "y"], delay: .seconds(5)))
        let job = await queue.submit(TextRequest(prompt: "1"))
        await queue.cancel(job.id)
        #expect(await collect(job).last == .cancelled(""))
    }
}

@Suite struct LocalModelLocationTests {
    private func makeCache() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let model = root.appending(path: "models--org--name")
        for snapshot in ["aaa", "bbb"] {
            let folder = model.appending(path: "snapshots/\(snapshot)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: folder.appending(path: "config.json"))
        }
        try FileManager.default.createDirectory(at: model.appending(path: "refs"), withIntermediateDirectories: true)
        try Data("bbb\n".utf8).write(to: model.appending(path: "refs/main"))
        return root
    }

    @Test func prefersTheMainRevision() throws {
        let root = try makeCache()
        let url = try LocalModelLocation.huggingFaceCache(repo: "org/name", cacheRoot: root).resolve()
        #expect(url.lastPathComponent == "bbb")
    }

    @Test func reportsAMissingModel() throws {
        let root = try makeCache()
        #expect(throws: LocalModelLocationError.notFound("org/other")) {
            try LocalModelLocation.huggingFaceCache(repo: "org/other", cacheRoot: root).resolve()
        }
    }
}
