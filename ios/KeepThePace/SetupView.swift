import PaceKit
import SwiftUI

/// Pick a destination and an arrive-by time, then start (or preview) a walk.
struct SetupView: View {
    let walk: WalkSession
    let saved: SavedData
    @State private var query = ""
    @State private var resolving = false
    @FocusState private var searchFocused: Bool

    private var units: Units { saved.units }
    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchField
                if searching {
                    resultsList
                } else {
                    chips
                }
                if let place = walk.planner.destination {
                    destinationCard(place)
                }
                arriveBySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            // Hidden while typing, so the keyboard and results get the room.
            if !searching { startBar }
        }
        .navigationTitle("Keep the Pace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    FavoritesView(saved: saved)
                } label: {
                    Image(systemName: "star")
                }
                .accessibilityLabel("Favorites")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(saved: saved)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .onAppear { walk.setupAppeared() }
        .onChange(of: query) { _, newValue in
            walk.search.update(query: newValue, near: walk.origin?.coordinate)
        }
        .onChange(of: searchFocused) { _, focused in
            if focused { walk.requestLocation() }
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField("Park, address, place…", text: $query)
                .focused($searchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("searchField")
            if searching {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 2) {
            if walk.search.failed {
                Text("Search isn't available right now. Try again, or type coordinates.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 8)
            } else if walk.search.results.isEmpty {
                Text(resolving ? "Finding place…" : "No matches yet. Keep typing, or try a street or landmark.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 8)
            }
            ForEach(walk.search.results) { result in
                Button {
                    pick(result)
                } label: {
                    PlaceRow(title: result.title, subtitle: result.subtitle)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Add to Favorites", systemImage: "star") {
                        Task {
                            if let place = await walk.search.resolve(result) { saved.favorites.add(place) }
                        }
                    }
                }
            }
        }
    }

    private func pick(_ result: SearchResult) {
        resolving = true
        Task {
            if let place = await walk.search.resolve(result) {
                walk.choose(place)
                query = ""
                searchFocused = false
            }
            resolving = false
        }
    }

    // MARK: Chips (favorites first, then recents)

    @ViewBuilder
    private var chips: some View {
        let favorites = saved.favorites.items
        let recents = saved.recents.places.filter { !saved.favorites.contains($0) }
        if !favorites.isEmpty || !recents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(favorites) { favorite in
                        chip(favorite.title, systemImage: "star.fill") { walk.choose(favorite.place) }
                    }
                    ForEach(recents, id: \.key) { place in
                        chip(place.name, systemImage: "clock") { walk.choose(place) }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .foregroundStyle(Theme.foreground)
                .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Destination

    private func destinationCard(_ place: Place) -> some View {
        let isFavorite = saved.favorites.contains(place)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.name).font(.title3.weight(.medium)).foregroundStyle(Theme.foreground)
                Spacer()
                if isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(Theme.accent).accessibilityLabel("Favorite")
                }
            }
            Text(place.area).font(.subheadline).foregroundStyle(Theme.muted)
            if let planned = walk.planner.plannedDistanceM {
                Text("\(Format.distance(meters: planned, units: units)) walk · ~\(Format.duration(seconds: Geo.walkEstimateSec(distanceM: planned)))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .contextMenu {
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "star.slash" : "star") {
                saved.toggleFavorite(place)
            }
        }
        .accessibilityIdentifier("destinationCard")
    }

    // MARK: Arrive by

    private var arriveBySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricLabel("Arrive by")
            if walk.planner.destination != nil, let arriveBy = walk.planner.arriveBy {
                HStack(spacing: 8) {
                    DatePicker(
                        "Arrive by",
                        selection: Binding(get: { arriveBy }, set: { walk.setArriveBy($0) }),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    Spacer()
                    stepButton("−1", label: "One minute earlier") { walk.bumpArriveBy(minutes: -1) }
                    stepButton("+1", label: "One minute later") { walk.bumpArriveBy(minutes: 1) }
                }
                Text("\(Format.clock(arriveBy)) · \(Format.duration(seconds: max(0, arriveBy.timeIntervalSinceNow))) from now")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Pick a destination first").font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }

    private func stepButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.monospacedDigit().weight(.medium))
                .frame(minWidth: 48, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Start

    private var startBar: some View {
        VStack(spacing: 10) {
            locationLine
            Button {
                walk.startWalking()
            } label: {
                Label("Start walking", systemImage: "location.north.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!walk.canStart)
            .accessibilityIdentifier("startButton")
            Text("on iPhone").font(.caption).foregroundStyle(Theme.muted)
            Button("Preview a walk") {
                walk.startDemo()
            }
            .buttonStyle(OutlineButtonStyle())
            .accessibilityIdentifier("demoButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    @ViewBuilder
    private var locationLine: some View {
        switch walk.location.access {
        case .allowed:
            if !walk.location.precise {
                Button("Precise Location is off. Tap to allow it for this walk.") { walk.location.requestPrecise() }
                    .font(.caption)
                    .foregroundStyle(Theme.late)
                    .multilineTextAlignment(.center)
            } else if walk.origin != nil {
                Text("GPS ready").font(.caption).foregroundStyle(Theme.early)
            } else {
                Text("Waiting for GPS…").font(.caption).foregroundStyle(Theme.muted)
            }
        case .denied:
            Text("Location is off. Turn it on in Settings to walk, or preview a walk.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        case .notDetermined:
            Button("Enable location to start a live walk") { walk.requestLocation() }
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }
}

private struct PlaceRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin").foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.foreground).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
