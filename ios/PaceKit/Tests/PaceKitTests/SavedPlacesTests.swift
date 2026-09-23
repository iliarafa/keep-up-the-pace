import Foundation
import Testing
@testable import PaceKit

@Suite struct SavedPlacesTests {
    func place(_ name: String, _ lat: Double = 40.75, _ lon: Double = -73.98) -> Place {
        Place(name: name, area: "Manhattan", coordinate: LatLon(lat: lat, lon: lon))
    }

    @Test func keyIgnoresCaseAndTinyCoordinateDifferences() {
        #expect(place("Bryant Park", 40.75361, -73.98321).key == place("bryant park", 40.75364, -73.98318).key)
        #expect(place("Bryant Park").key != place("Bryant Park", 40.76).key)
        #expect(place("Bryant Park", 40.7536, -73.9832).key == "bryant park|40.754|-73.983")
    }

    @Test func favoritesAddOnceAndRemove() {
        var f = Favorites()
        let added = f.add(place("Home"))
        let addedAgain = f.add(place("home"))
        #expect(added)
        #expect(!addedAgain)
        #expect(f.contains(place("Home")))
        f.remove(place("Home"))
        #expect(f.items.isEmpty)
    }

    @Test func favoritesMoveLikeSwiftUILists() {
        var f = Favorites()
        for name in ["A", "B", "C", "D"] { f.add(place(name)) }
        f.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(f.items.map(\.place.name) == ["B", "C", "A", "D"])
        f.move(fromOffsets: IndexSet([2, 3]), toOffset: 0)
        #expect(f.items.map(\.place.name) == ["A", "D", "B", "C"])
        f.remove(atOffsets: IndexSet(integer: 1))
        #expect(f.items.map(\.place.name) == ["A", "B", "C"])
    }

    @Test func renameSetsOrClearsTheLabel() {
        var f = Favorites()
        f.add(place("350 5th Ave"))
        let id = f.items[0].id
        f.rename(id: id, to: "  Work ")
        #expect(f.items[0].title == "Work")
        f.rename(id: id, to: "   ")
        #expect(f.items[0].label == nil)
        #expect(f.items[0].title == "350 5th Ave")
    }

    @Test func recentsKeepSixNewestWithoutDuplicates() {
        var r = Recents()
        for i in 1...7 { r.record(place("P\(i)", 40 + Double(i) / 100)) }
        #expect(r.places.map(\.name) == ["P7", "P6", "P5", "P4", "P3", "P2"])
        r.record(place("P4", 40.04))
        #expect(r.places.map(\.name) == ["P4", "P7", "P6", "P5", "P3", "P2"])
    }
}
