import Foundation

public enum LocalModelLocationError: LocalizedError, Equatable {
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let name): "The model \(name) was not found on this device."
        }
    }
}

/// Where a model's weights live on disk. Nothing is downloaded.
public enum LocalModelLocation: Sendable, Hashable {
    case directory(URL)
    /// A model in the Hugging Face cache, such as `mlx-community/Qwen3-8B-4bit`.
    /// `cacheRoot` defaults to `HF_HUB_CACHE`, then `HF_HOME/hub`, then `~/.cache/huggingface/hub`.
    case huggingFaceCache(repo: String, cacheRoot: URL? = nil)

    public func resolve() throws -> URL {
        switch self {
        case .directory(let url):
            guard Self.isModel(url) else { throw LocalModelLocationError.notFound(url.path) }
            return url
        case .huggingFaceCache(let repo, let cacheRoot):
            let folder = "models--" + repo.replacingOccurrences(of: "/", with: "--")
            let model = (cacheRoot ?? Self.defaultCacheRoot()).appending(path: folder)
            let snapshots = model.appending(path: "snapshots")
            if let main = try? String(contentsOf: model.appending(path: "refs/main"), encoding: .utf8) {
                let pinned = snapshots.appending(path: main.trimmingCharacters(in: .whitespacesAndNewlines))
                if Self.isModel(pinned) { return pinned }
            }
            let found = (try? FileManager.default.contentsOfDirectory(
                at: snapshots, includingPropertiesForKeys: nil)) ?? []
            guard let snapshot = found.sorted(by: { $0.path < $1.path }).first(where: Self.isModel) else {
                throw LocalModelLocationError.notFound(repo)
            }
            return snapshot
        }
    }

    private static func isModel(_ directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: "config.json").path)
    }

    private static func defaultCacheRoot() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let hub = environment["HF_HUB_CACHE"], !hub.isEmpty {
            return URL(fileURLWithPath: hub)
        }
        if let home = environment["HF_HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home).appending(path: "hub")
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".cache/huggingface/hub")
    }
}
