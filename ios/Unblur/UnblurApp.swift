import SwiftUI

@main
struct UnblurApp: App {
    var body: some Scene {
        WindowGroup {
            EpisodeListView(viewModel: Self.makeViewModel())
        }
    }

    private static func makeViewModel() -> EpisodeListViewModel {
        if let mode = UITestMode.fromLaunchEnvironment() {
            return EpisodeListViewModel(service: UITestEpisodeService(mode: mode))
        }
        return EpisodeListViewModel()
    }
}
