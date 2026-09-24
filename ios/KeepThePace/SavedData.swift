import Foundation
import Observation
import PaceKit

/// Settings, favorites, recents and the walk in progress, kept in the App Group's defaults so the
/// Live Activity extension can read them later. Every change is saved immediately.
@MainActor
@Observable
final class SavedData {
    static let appGroup = "group.com.iliasrafailidis.delta"

    private enum Key {
        static let settings = "settings.v1"
        static let favorites = "favorites.v1"
        static let recents = "recents.v1"
        static let activeWalk = "activeWalk.v1"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { save(settings, forKey: Key.settings) }
    }

    var favorites: Favorites {
        didSet { save(favorites, forKey: Key.favorites) }
    }

    var recents: Recents {
        didSet { save(recents, forKey: Key.recents) }
    }

    /// The real walk in progress, so it can be resumed after a force-quit; nil when none is running.
    @ObservationIgnored var activeWalk: ActiveWalk? {
        didSet {
            if let activeWalk {
                save(activeWalk, forKey: Key.activeWalk)
            } else {
                defaults.removeObject(forKey: Key.activeWalk)
            }
        }
    }

    init(defaults: UserDefaults = UserDefaults(suiteName: SavedData.appGroup) ?? .standard) {
        self.defaults = defaults
        settings = Self.load(AppSettings.self, from: defaults, forKey: Key.settings) ?? AppSettings()
        favorites = Self.load(Favorites.self, from: defaults, forKey: Key.favorites) ?? Favorites()
        recents = Self.load(Recents.self, from: defaults, forKey: Key.recents) ?? Recents()
        activeWalk = Self.load(ActiveWalk.self, from: defaults, forKey: Key.activeWalk)
    }

    var units: Units {
        settings.units.resolved(for: .current)
    }

    func toggleFavorite(_ place: Place) {
        if favorites.contains(place) {
            favorites.remove(place)
        } else {
            favorites.add(place)
        }
    }

    private func save(_ value: some Encodable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, from defaults: UserDefaults, forKey key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
