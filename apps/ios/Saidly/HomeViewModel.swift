import Domain
import Foundation
import Networking

@Observable @MainActor final class HomeViewModel {
    private let apiClient: APIClient
    private(set) var state: State = .loading

    enum State: Equatable {
        case loading
        case loaded(serverUserId: String)
        case failed(AppError)
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        state = .loading
        do {
            let me = try await apiClient.me()
            state = .loaded(serverUserId: me.userId)
        } catch {
            state = .failed(error)
        }
    }
}
