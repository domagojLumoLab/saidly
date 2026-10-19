import Domain
import AuthFeature
import Auth

@MainActor final class AppDependencies {
    let authRepository: any AuthRepository
    let sessionModel: SessionModel
    
    init() {
        authRepository = FirebaseAuthRepository()
        sessionModel = SessionModel(authRepository: authRepository)
    }
    
    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(authRepository: authRepository)
    }
}

