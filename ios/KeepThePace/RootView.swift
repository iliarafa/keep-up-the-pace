import SwiftUI

struct RootView: View {
    let walk: WalkSession
    let saved: SavedData
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch walk.phase {
            case .setup:
                NavigationStack {
                    SetupView(walk: walk, saved: saved)
                }
            case .walk:
                WalkView(walk: walk, saved: saved)
            case .arrived:
                ArrivedView(walk: walk, saved: saved)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, newPhase in walk.sceneChanged(newPhase) }
    }
}
