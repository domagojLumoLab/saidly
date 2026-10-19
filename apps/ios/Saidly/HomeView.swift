import Domain
import SwiftUI

struct HomeView: View {
    let user: AppUser
    let onSignOut: @MainActor () -> Void

    var body: some View {
        VStack {
            Text(user.email ?? "…")
            Button("Sign out", action: onSignOut)
        }
    }
}

#Preview {
    HomeView(user: AppUser(id: "1", email: "test@saidly.app"), onSignOut: {})
}
