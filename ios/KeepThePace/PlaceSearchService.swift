import MapKit
import Observation
import PaceKit

struct SearchResult: Identifiable {
    enum Source {
        case coordinates(Place)
        case completion(MKLocalSearchCompletion)
    }

    let id: String
    let title: String
    let subtitle: String
    let source: Source
}

/// Type-ahead place search from Apple Maps, biased to the user's area. Typed coordinates
/// ("40.7536, -73.9832") become a result directly, without a network call.
@MainActor
@Observable
final class PlaceSearchService: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [SearchResult] = []
    private(set) var failed = false
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String, near origin: LatLon?) {
        failed = false
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let place = CoordinateParser.parse(trimmed) {
            completer.cancel()
            results = [SearchResult(id: "coordinates", title: place.name, subtitle: place.area, source: .coordinates(place))]
            return
        }
        guard trimmed.count >= 2 else {
            completer.cancel()
            results = []
            return
        }
        if let origin {
            completer.region = MKCoordinateRegion(
                center: origin.clCoordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        }
        completer.queryFragment = trimmed
    }

    /// The place behind a result, looked up in Apple Maps for type-ahead completions.
    func resolve(_ result: SearchResult) async -> Place? {
        switch result.source {
        case .coordinates(let place):
            return place
        case .completion(let completion):
            let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            guard let item = try? await search.start().mapItems.first else { return nil }
            return Place(name: result.title, area: result.subtitle, coordinate: LatLon(item.placemark.coordinate))
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Delegate calls arrive on the main thread, where the completer was created.
        MainActor.assumeIsolated {
            results = self.completer.results.enumerated().map { index, completion in
                SearchResult(
                    id: "\(index)|\(completion.title)|\(completion.subtitle)", title: completion.title,
                    subtitle: completion.subtitle, source: .completion(completion))
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            results = []
            failed = true
        }
    }
}
