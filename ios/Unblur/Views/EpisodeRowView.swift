import SwiftUI

struct EpisodeRowView: View {
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
    }

    private var subtitle: String {
        let date = RelativeDateFormatter.format(episode.publishDate)
        let duration = DurationFormatter.format(episode.duration)
        return "\(date) · \(duration)"
    }

    @ViewBuilder
    private var artwork: some View {
        let url = episode.artworkUrl.flatMap(URL.init(string:))
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                artworkPlaceholder
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
