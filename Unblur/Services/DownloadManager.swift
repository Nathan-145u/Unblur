//
//  DownloadManager.swift
//  Unblur
//

import Foundation
import Observation

@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    /// episodeID → progress 0…1 (in-flight only)
    private(set) var activeProgress: [UUID: Double] = [:]
    var lastError: String?

    private var session: URLSession!
    private var tasks: [Int: PendingDownload] = [:]

    private struct PendingDownload {
        let episodeID: UUID
        let onComplete: (Result<String, Error>) -> Void
    }

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    /// Returns local filename on completion.
    func download(
        episodeID: UUID,
        from remoteURL: String,
        onComplete: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: remoteURL) else {
            onComplete(.failure(NSError(domain: "Unblur", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = PendingDownload(episodeID: episodeID, onComplete: onComplete)
        activeProgress[episodeID] = 0
        task.resume()
    }

    func progress(for episodeID: UUID) -> Double? { activeProgress[episodeID] }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let id = downloadTask.taskIdentifier
        Task { @MainActor in
            if let p = self.tasks[id] {
                self.activeProgress[p.episodeID] = pct
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier
        // Move file synchronously to avoid temp cleanup before async hop.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "\(UUID().uuidString).mp3"
        let dest = docs.appendingPathComponent(filename)
        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            Task { @MainActor in
                if let p = self.tasks.removeValue(forKey: id) {
                    self.activeProgress[p.episodeID] = nil
                    p.onComplete(.failure(error))
                }
            }
            return
        }
        Task { @MainActor in
            if let p = self.tasks.removeValue(forKey: id) {
                self.activeProgress[p.episodeID] = nil
                p.onComplete(.success(filename))
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = task.taskIdentifier
        Task { @MainActor in
            if let p = self.tasks.removeValue(forKey: id) {
                self.activeProgress[p.episodeID] = nil
                self.lastError = error.localizedDescription
                p.onComplete(.failure(error))
            }
        }
    }
}
