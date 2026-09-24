import SwiftUI

@main
struct KeepThePaceApp: App {
    @State private var saved: SavedData
    @State private var walk: WalkSession

    init() {
        let saved = SavedData()
        _saved = State(initialValue: saved)
        _walk = State(initialValue: WalkSession(saved: saved))
    }

    var body: some Scene {
        WindowGroup {
            RootView(walk: walk, saved: saved)
        }
    }
}
