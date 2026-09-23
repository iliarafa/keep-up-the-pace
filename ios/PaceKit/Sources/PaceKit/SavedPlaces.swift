import Foundation

extension Place {
    /// Identity for de-duplication: lower-cased name plus coordinates to 3 decimals (about 100 m),
    /// the key the web uses to merge search results (`placeKey` in `src/lib/geocode.ts`).
    public var key: String {
        "\(name.lowercased())|\(JSNumber.toFixed(coordinate.lat, 3))|\(JSNumber.toFixed(coordinate.lon, 3))"
    }
}

public struct Favorite: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var place: Place
    /// Optional custom name, e.g. "Home".
    public var label: String?

    public init(id: UUID = UUID(), place: Place, label: String? = nil) {
        self.id = id
        self.place = place
        self.label = label
    }

    public var title: String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? place.name : trimmed
    }
}

/// The user's favorite places, in the user's order.
public struct Favorites: Codable, Equatable, Sendable {
    public private(set) var items: [Favorite]

    public init(items: [Favorite] = []) {
        self.items = items
    }

    public func contains(_ place: Place) -> Bool {
        items.contains { $0.place.key == place.key }
    }

    /// Adds the place at the end. Returns false if it is already a favorite.
    @discardableResult
    public mutating func add(_ place: Place) -> Bool {
        guard !contains(place) else { return false }
        items.append(Favorite(place: place))
        return true
    }

    public mutating func remove(_ place: Place) {
        items.removeAll { $0.place.key == place.key }
    }

    public mutating func remove(atOffsets offsets: IndexSet) {
        items = items.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
    }

    /// Same contract as SwiftUI's `move(fromOffsets:toOffset:)`: `toOffset` is an index in the
    /// list before the move.
    public mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.map { items[$0] }
        let insertAt = destination - offsets.filter { $0 < destination }.count
        remove(atOffsets: offsets)
        items.insert(contentsOf: moving, at: insertAt)
    }

    public mutating func rename(id: UUID, to label: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].label = trimmed.isEmpty ? nil : trimmed
    }
}

/// The last few destinations walked to, newest first.
public struct Recents: Codable, Equatable, Sendable {
    public static let limit = 6
    public private(set) var places: [Place]

    public init(places: [Place] = []) {
        self.places = Array(places.prefix(Self.limit))
    }

    /// Decodes through the same cap, so stored data can never hold more than `limit` places.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(places: try values.decode([Place].self, forKey: .places))
    }

    public mutating func record(_ place: Place) {
        places = Array(([place] + places.filter { $0.key != place.key }).prefix(Self.limit))
    }
}
