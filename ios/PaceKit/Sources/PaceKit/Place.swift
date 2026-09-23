public struct Place: Codable, Hashable, Sendable {
    public var name: String
    public var area: String
    public var coordinate: LatLon

    public init(name: String, area: String, coordinate: LatLon) {
        self.name = name
        self.area = area
        self.coordinate = coordinate
    }
}
