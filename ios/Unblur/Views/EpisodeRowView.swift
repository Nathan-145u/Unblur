import SwiftUI
import Nuke
import NukeUI

struct EpisodeRowView: View {
    private static let artworkDisplayPoints: CGFloat = 60
    private static let artworkTargetPixels: CGFloat = artworkDisplayPoints * 2
    private static let artworkProcessors: [any ImageProcessing] = [
        ImageProcessors.Resize(
            size: CGSize(width: artworkTargetPixels, height: artworkTargetPixels),
            contentMode: .aspectFill,
            crop: true
        ),
    ]

    let episode: Episode

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("episodeRow-\(episode.title)")
    }

    private var subtitle: String {
        let date = RelativeDateFormatter.format(episode.publishDate)
        let duration = DurationFormatter.format(episode.duration)
        return "\(date) · \(duration)"
    }

    @ViewBuilder
    private var artwork: some View {
        let url = episode.artworkUrl.flatMap(URL.init(string:))
        LazyImage(request: artworkRequest(for: url)) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: Self.artworkDisplayPoints, height: Self.artworkDisplayPoints)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func artworkRequest(for url: URL?) -> ImageRequest? {
        guard let url else { return nil }
        return ImageRequest(url: url, processors: Self.artworkProcessors)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}
