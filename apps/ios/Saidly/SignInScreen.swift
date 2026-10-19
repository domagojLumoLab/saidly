import AuthFeature
import SwiftUI

struct SignInScreen: View {
    @State private var viewModel: SignInViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: dependencies.makeSignInViewModel())
    }

    var body: some View {
        SignInView(viewModel: viewModel)
    }
}
