import SwiftUI

@main
struct TrailQuestApp: App {
    @StateObject private var location = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(location)
        }
    }
}
