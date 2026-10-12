import Domain
import SwiftUI

struct ContentView: View {
    let appUser = AppUser(id: "Ab12#321jdawk", email: "test@saidly.app")

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(appUser.email ?? "No email")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
