import SwiftUI

struct EpisodeRowView: View {
    let episode: EpisodeDTO

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: episode.artworkUrl.flatMap(URL.init)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(episode.formattedDate)
                    Text("·")
                    Text(episode.formattedDuration)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
