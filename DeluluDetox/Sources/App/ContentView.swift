import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "brain.head.profile")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("DeluluDetox")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
