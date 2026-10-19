import SwiftUI
import AuthFeature

struct RootView: View {
    let dependencies: AppDependencies
    
    var body: some View {
        Group {
            switch dependencies.sessionModel.state {
            case .unknown: ProgressView()
            case .signedOut: SignInScreen(dependencies: dependencies)
            case .signedIn(let user): HomeView(user: user, onSignOut: dependencies.sessionModel.signOut)
            }
        }
        .task { await dependencies.sessionModel.start() }
    }
}
