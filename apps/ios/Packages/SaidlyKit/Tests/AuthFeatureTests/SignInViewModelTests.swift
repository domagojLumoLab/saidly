import Testing
import Domain
import AuthFeature

@MainActor @Suite struct SignInViewModelTests {
    
    private func makeViewModel(result: Result<Void, AppError> = .success(())) -> SignInViewModel {
        SignInViewModel(authRepository: FakeAuthRepository(signInResult: result))
    }
    
    @Test func initialStateIsIdleAndCannotSubmit() {
        let viewModel = makeViewModel()
        
        #expect(viewModel.canSubmit == false)
        #expect(viewModel.state == .idle)
    }
    
    @Test func filledFieldsEnableSubmit() {
        let viewModel = makeViewModel()
        viewModel.email = "b@test.com"
        viewModel.password = "123456"
        
        #expect(viewModel.canSubmit == true)
    }
    
    @Test func successfulSignInResetsToIdle() async {
        let viewModel = makeViewModel()
        viewModel.email = "b@test.com"
        viewModel.password = "123456"
        
        await viewModel.signIn()
        
        #expect(viewModel.state == .idle)
    }
    
    @Test func failedSignInSetsFailedState() async {
        let viewModel = makeViewModel(result: .failure(.invalidCredentials))
        viewModel.email = "b@test.com"
        viewModel.password = "123456"
        
        await viewModel.signIn()
        
        #expect(viewModel.state == .failed(.invalidCredentials))
    }
    
    @Test func emptyFieldsPreventSignIn() async {
        let viewModel = makeViewModel()
        
        await viewModel.signIn()
        
        #expect(viewModel.state == .idle)
    }
}
