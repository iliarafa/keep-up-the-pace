import MapKit
import PaceKit

/// Walking distance along streets from Apple Maps, or nil when there is no route (the app then
/// uses the straight line).
@MainActor
struct RouteService {
    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.clCoordinate))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.distance
        } catch {
            return nil
        }
    }
}

extension RouteService: RouteProviding {}
