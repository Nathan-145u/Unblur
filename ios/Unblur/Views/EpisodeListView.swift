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
            if viewModel.refreshFailed {
                refreshErrorBanner
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
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
            } else if viewModel.paginationFailed {
                paginationErrorRow
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var refreshErrorBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Refresh failed")
                .font(.subheadline)
            Spacer()
            Button("Dismiss") {
                Task { await viewModel.refresh() }
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
        .foregroundStyle(.red)
    }

    private var paginationErrorRow: some View {
        Button {
            Task { await viewModel.loadMore() }
        } label: {
            HStack {
                Spacer()
                Image(systemName: "arrow.clockwise")
                Text("Unable to load more. Tap to retry")
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 12)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
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
        guard viewModel.hasMore, !viewModel.isLoadingMore, !viewModel.paginationFailed else { return }
        let threshold = max(viewModel.episodes.count - 5, 0)
        if index >= threshold {
            Task { await viewModel.loadMore() }
        }
    }
}
