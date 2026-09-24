import PaceKit
import SwiftUI

/// Reorder, delete and name favorite places.
struct FavoritesView: View {
    @Bindable var saved: SavedData
    @State private var renaming: Favorite?
    @State private var draftName = ""

    var body: some View {
        Group {
            if saved.favorites.items.isEmpty {
                ContentUnavailableView(
                    "No favorites yet", systemImage: "star",
                    description: Text("Long-press a search result or the destination card to add a place."))
            } else {
                List {
                    ForEach(saved.favorites.items) { favorite in
                        Button {
                            draftName = favorite.label ?? ""
                            renaming = favorite
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(favorite.title).foregroundStyle(Theme.foreground)
                                Text(favorite.label == nil ? favorite.place.area : favorite.place.name)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .onDelete { saved.favorites.remove(atOffsets: $0) }
                    .onMove { saved.favorites.move(fromOffsets: $0, toOffset: $1) }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .toolbar { EditButton() }
            }
        }
        .background(Theme.background)
        .navigationTitle("Favorites")
        .alert("Name this place", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("e.g. Home", text: $draftName)
            Button("Save") {
                if let renaming { saved.favorites.rename(id: renaming.id, to: draftName) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("Leave it empty to use the place's own name.")
        }
    }
}
