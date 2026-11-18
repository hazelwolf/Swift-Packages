import Foundation

public enum ModelJobEvent: Sendable, Equatable {
    case queued
    case started
    case text(String)
    case finished(String)
    case cancelled(String)
    case failed(String)
}

public struct ModelJob: Sendable {
    public let id: UUID
    public let events: AsyncStream<ModelJobEvent>
}

/// Runs local model jobs strictly one at a time, in the order they were submitted,
/// because a local model holds most of the machine's memory while it generates.
public actor ModelJobQueue {
    private struct Pending {
        let id: UUID
        let request: TextRequest
        let continuation: AsyncStream<ModelJobEvent>.Continuation
    }

    private let backend: any TextGenerationBackend
    private var pending: [Pending] = []
    private var runningID: UUID?
    private var runningTask: Task<Void, Never>?

    public init(backend: any TextGenerationBackend) {
        self.backend = backend
    }

    public func submit(_ request: TextRequest) -> ModelJob {
        let id = UUID()
        let (events, continuation) = AsyncStream.makeStream(of: ModelJobEvent.self)
        continuation.yield(.queued)
        pending.append(Pending(id: id, request: request, continuation: continuation))
        startNextIfIdle()
        return ModelJob(id: id, events: events)
    }

    public func cancel(_ id: UUID) {
        if let index = pending.firstIndex(where: { $0.id == id }) {
            let job = pending.remove(at: index)
            job.continuation.yield(.cancelled(""))
            job.continuation.finish()
        } else if runningID == id {
            runningTask?.cancel()
        }
    }

    private func startNextIfIdle() {
        guard runningID == nil, !pending.isEmpty else { return }
        let job = pending.removeFirst()
        runningID = job.id
        let backend = backend
        runningTask = Task {
            let outcome = await Self.run(job.request, on: backend, reportingTo: job.continuation)
            job.continuation.yield(outcome)
            job.continuation.finish()
            self.jobDidFinish()
        }
    }

    private func jobDidFinish() {
        runningID = nil
        runningTask = nil
        startNextIfIdle()
    }

    private static func run(
        _ request: TextRequest,
        on backend: any TextGenerationBackend,
        reportingTo continuation: AsyncStream<ModelJobEvent>.Continuation
    ) async -> ModelJobEvent {
        continuation.yield(.started)
        var filter = ThinkFilter()
        var text = ""
        do {
            for try await chunk in try await backend.generate(request) {
                try Task.checkCancellation()
                let visible = filter.consume(chunk)
                if !visible.isEmpty {
                    text += visible
                    continuation.yield(.text(visible))
                }
            }
            try Task.checkCancellation()
            let tail = filter.finish()
            if !tail.isEmpty {
                text += tail
                continuation.yield(.text(tail))
            }
            return .finished(text)
        } catch is CancellationError {
            return .cancelled(text)
        } catch {
            return Task.isCancelled ? .cancelled(text) : .failed(error.localizedDescription)
        }
    }
}
