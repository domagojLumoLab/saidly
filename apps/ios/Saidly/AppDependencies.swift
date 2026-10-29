import Auth
import AuthFeature
import Domain
import Foundation
import Networking

@MainActor final class AppDependencies {
    let authRepository: any AuthRepository
    let sessionModel: SessionModel
    let apiClient: APIClient

    init() {
        let firebaseAuth = FirebaseAuthRepository()
        authRepository = firebaseAuth
        sessionModel = SessionModel(authRepository: firebaseAuth)
        apiClient = APIClient(baseURL: Self.apiBaseURL(), tokenProvider: firebaseAuth)
    }

    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(authRepository: authRepository)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(apiClient: apiClient)
    }

    private static func apiBaseURL() -> URL {
        guard let apiBaseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: apiBaseURL)
        else { fatalError("API_BASE_URL missing or invalid") }
        return url
    }
}
