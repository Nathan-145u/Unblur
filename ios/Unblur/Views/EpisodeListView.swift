import SwiftUI

struct EpisodeListView: View {
    @State private var viewModel = EpisodeListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()

                case .loaded:
                    loadedContent

                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Unblur")
        }
        .task {
            await viewModel.loadInitialPage()
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        if viewModel.episodes.isEmpty && !viewModel.isConnected {
            emptyState(
                icon: "wifi.slash",
                title: "No Internet Connection",
                subtitle: nil
            )
        } else if viewModel.episodes.isEmpty {
            emptyState(
                icon: "headphones",
                title: "No Episodes Yet",
                subtitle: "Pull down to sync."
            )
        } else {
            episodeList
        }
    }

    // MARK: - Episode List

    private var episodeList: some View {
        List {
            ForEach(viewModel.episodes) { episode in
                EpisodeRowView(episode: episode)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: episode)
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

            if let error = viewModel.paginationError {
                paginationErrorRow(error)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Error States

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.bordered)
        }
    }

    private func paginationErrorRow(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                Task { await viewModel.retryLoadMore() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String?) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let subtitle {
                Text(subtitle)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = viewModel.toastMessage {
            Text(message)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.toastMessage)
        }
    }
}
