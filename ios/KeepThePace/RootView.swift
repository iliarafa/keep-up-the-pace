import SwiftUI

struct RootView: View {
    let walk: WalkSession
    let saved: SavedData

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
    }
}
