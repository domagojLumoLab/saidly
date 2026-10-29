import Domain
import SwiftUI

struct HomeScreen: View {
    let user: AppUser
    let onSignOut: @MainActor () -> Void
    @State private var viewModel: HomeViewModel

    init(user: AppUser, dependencies: AppDependencies, onSignOut: @escaping @MainActor () -> Void) {
        self.user = user
        self.onSignOut = onSignOut
        _viewModel = State(initialValue: dependencies.makeHomeViewModel())
    }

    var body: some View {
        HomeView(viewModel: viewModel, user: user, onSignOut: onSignOut)
    }
}
