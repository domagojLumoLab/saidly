import Domain
import SwiftUI

struct HomeView: View {
    let user: AppUser
    let onSignOut: @MainActor () -> Void
    let viewModel: HomeViewModel

    init(viewModel: HomeViewModel, user: AppUser, onSignOut: @escaping @MainActor () -> Void) {
        self.viewModel = viewModel
        self.user = user
        self.onSignOut = onSignOut
    }

    var body: some View {
        VStack {
            Text(user.email ?? "–")
            Text(user.id)
            switch viewModel.state {
            case .loading: ProgressView()
            case .loaded(let serverUserId):
                Text(serverUserId == user.id ? "✅ uid matches" : "❌ uid mismatch")
                Text(serverUserId)
            case .failed(let error): Text(error.message)
            }
            Button("Sign out", action: onSignOut)
        }.task {
            await viewModel.load()
        }

    }
}

//#Preview {
//    HomeView(user: AppUser(id: "1", email: "test@saidly.app"), onSignOut: {})
//}
