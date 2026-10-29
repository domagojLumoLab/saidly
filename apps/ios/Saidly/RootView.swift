import AuthFeature
import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        Group {
            switch dependencies.sessionModel.state {
            case .unknown: ProgressView()
            case .signedOut: SignInScreen(dependencies: dependencies)
            case .signedIn(let user):
                HomeScreen(
                    user: user, dependencies: dependencies,
                    onSignOut: dependencies.sessionModel.signOut)
            }
        }
        .task { await dependencies.sessionModel.start() }
    }
}
