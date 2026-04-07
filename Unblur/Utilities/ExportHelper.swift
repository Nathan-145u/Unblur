//
//  ExportHelper.swift
//  Unblur — v0.4 subtitle export
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum ExportFormat: String {
    case srt, vtt, txt
}

enum ExportHelper {
    static func render(episode: Episode, format: ExportFormat) -> String {
        let subs = episode.subtitles.sorted { $0.index < $1.index }
        switch format {
        case .srt:
            return subs.enumerated().map { (i, s) in
                "\(i + 1)\n\(srtTime(s.startTime)) --> \(srtTime(s.endTime))\n\(s.text)\n"
            }.joined(separator: "\n")
        case .vtt:
            let body = subs.map { s in
                "\(vttTime(s.startTime)) --> \(vttTime(s.endTime))\n\(s.text)\n"
            }.joined(separator: "\n")
            return "WEBVTT\n\n" + body
        case .txt:
            return subs.map { $0.text }.joined(separator: "\n")
        }
    }

    static func writeFile(episode: Episode, format: ExportFormat) -> URL? {
        let content = render(episode: episode, format: format)
        let safeTitle = episode.title.replacingOccurrences(of: "/", with: "-")
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle).\(format.rawValue)")
        try? content.write(to: tmp, atomically: true, encoding: .utf8)
        return tmp
    }

    @MainActor
    static func share(episode: Episode, format: ExportFormat) {
        guard let url = writeFile(episode: episode, format: format) else { return }
        #if os(iOS)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController
        else { return }
        var presenter = root
        while let p = presenter.presentedViewController { presenter = p }
        presenter.present(av, animated: true)
        #endif
    }

    private static func srtTime(_ t: TimeInterval) -> String {
        let total = max(t, 0)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let ms = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    private static func vttTime(_ t: TimeInterval) -> String {
        let total = max(t, 0)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let ms = Int((total - floor(total)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
    }
}
