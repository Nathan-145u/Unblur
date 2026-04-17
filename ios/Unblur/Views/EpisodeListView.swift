import SwiftUI

struct EpisodeListView: View {
    @State private var viewModel: EpisodeListViewModel

    init(viewModel: EpisodeListViewModel = EpisodeListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Unblur")
        }
        .task {
            if viewModel.loadState == .idle {
                await viewModel.loadEpisodes()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            loadingView
        case .loaded:
            if viewModel.episodes.isEmpty {
                emptyView
            } else {
                episodeList
            }
        case .error:
            errorView
        case .offline:
            offlineView
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No episodes yet")
                .font(.headline)
            Text("Pull down to refresh")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var episodeList: some View {
        List {
            ForEach(Array(viewModel.episodes.enumerated()), id: \.element.id) { index, episode in
                EpisodeRowView(episode: episode)
                    .onAppear {
                        handleRowAppear(at: index)
                    }
            }
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var errorView: some View {
        retryState(
            symbol: "wifi.exclamationmark",
            title: "Unable to load episodes",
            buttonTitle: "Tap to retry"
        )
    }

    private var offlineView: some View {
        retryState(
            symbol: "wifi.slash",
            title: "No internet connection",
            buttonTitle: "Tap to retry"
        )
    }

    private func retryState(symbol: String, title: String, buttonTitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Button(buttonTitle) {
                Task { await viewModel.loadEpisodes() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleRowAppear(at index: Int) {
        let threshold = max(viewModel.episodes.count - 5, 0)
        if index >= threshold {
            Task { await viewModel.loadMore() }
        }
    }
}
