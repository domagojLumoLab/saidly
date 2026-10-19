import SwiftUI
import Domain

public struct SignInView: View {
    @Bindable var viewModel: SignInViewModel

    public init(viewModel: SignInViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)

            Button {
                Task { await viewModel.signIn() }
            } label: {
                Group {
                    if viewModel.state == .signingIn {
                        ProgressView()
                    } else {
                        Text("Sign in")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canSubmit)

            if case .failed(let error) = viewModel.state {
                Text(error.message)
                    .foregroundStyle(.red)
            }
        }
        .onSubmit {
            Task { await viewModel.signIn() }
        }
    }
}

#Preview("Idle") {
    SignInView(viewModel: SignInViewModel(authRepository: PreviewAuthRepository()))
}

#Preview("Failed") {
    let vm = SignInViewModel(authRepository: PreviewAuthRepository(behavior: .fails(.invalidCredentials)))
    vm.email = "test@test.com"
    vm.password = "wrong"
    return SignInView(viewModel: vm)
        .task { await vm.signIn() }
}

#Preview("Signing In") {
    let vm = SignInViewModel(authRepository: PreviewAuthRepository(behavior: .hangs))
    vm.email = "test@test.com"
    vm.password = "123456"
    return SignInView(viewModel: vm)
        .task { await vm.signIn() }
}
