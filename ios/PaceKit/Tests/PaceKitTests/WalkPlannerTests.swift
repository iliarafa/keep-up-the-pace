import Foundation
import Testing
@testable import PaceKit

@Suite struct WalkPlannerTests {
    // 2027-01-15 12:00:30 UTC — mid-minute, so rounding up to the minute is visible.
    var now: Date { utcDate(day: 15, hour: 12, minute: 0, second: 30) }
    let origin = LatLon(lat: 40.7527, lon: -73.9772)
    let park = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func utcDate(day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2027, month: 1, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test func choosingSetsAStraightLinePlan() {
        var p = WalkPlanner()
        let id = p.choose(park, from: origin, now: now)
        let crow = Geo.haversineM(origin, park.coordinate)
        #expect(id != nil)
        #expect(p.destination == park)
        #expect(p.plannedDistanceM == crow)
        #expect(!p.plannedFromRoute)
        #expect(p.arriveBy == Geo.roundUpToMinute(now + max(crow, 80) / 1.34))
    }

    @Test func noOriginLeavesTheDistanceUnknown() {
        var p = WalkPlanner()
        let id = p.choose(park, from: nil, now: now)
        #expect(id == nil)
        #expect(p.plannedDistanceM == nil)
        #expect(!p.plannedFromRoute)
        #expect(p.arriveBy == Geo.roundUpToMinute(now + 1200 / 1.34))  // the placeholder only sets the time
    }

    @Test func shortTripsAreEstimatedAsEightyMetres() {
        let arrive = WalkPlanner.defaultArriveBy(distanceM: 10, now: now)
        #expect(arrive == Geo.roundUpToMinute(now + 80 / 1.34))
    }

    @Test func routeUpgradesThePlan() {
        var p = WalkPlanner()
        let id = p.choose(park, from: origin, now: now)!
        p.routeResolved(planID: id, distanceM: 900, now: now)
        #expect(p.plannedFromRoute)
        #expect(p.plannedDistanceM == 900)
        #expect(p.arriveBy == Geo.roundUpToMinute(now + 900 / 1.34))
    }

    @Test func routeIsIgnoredAfterEditsNewPicksOrFailure() {
        var edited = WalkPlanner()
        let id1 = edited.choose(park, from: origin, now: now)!
        edited.bump(minutes: 1, now: now)
        let editedTime = edited.arriveBy
        edited.routeResolved(planID: id1, distanceM: 900, now: now)
        #expect(!edited.plannedFromRoute)
        #expect(edited.arriveBy == editedTime)

        var repicked = WalkPlanner()
        let stale = repicked.choose(park, from: origin, now: now)!
        _ = repicked.choose(park, from: origin, now: now)
        repicked.routeResolved(planID: stale, distanceM: 900, now: now)
        #expect(!repicked.plannedFromRoute)

        var failed = WalkPlanner()
        let id3 = failed.choose(park, from: origin, now: now)!
        failed.routeResolved(planID: id3, distanceM: nil, now: now)
        #expect(!failed.plannedFromRoute)
    }

    @Test func bumpMovesByMinutesButNeverUnderAMinuteAway() {
        var p = WalkPlanner()
        _ = p.choose(park, from: origin, now: now)
        let before = p.arriveBy!
        p.bump(minutes: 1, now: now)
        #expect(p.arriveBy == before + 60)
        p.bump(minutes: -600, now: now)
        #expect(p.arriveBy == now + 60)
    }

    @Test func bumpWithoutATimeStartsFromFifteenMinutes() {
        var p = WalkPlanner()
        p.bump(minutes: 1, now: now)
        #expect(p.arriveBy == now + 16 * 60)
    }

    @Test func pickedTimeIsTodayOrTomorrow() {
        var p = WalkPlanner()
        p.setArriveBy(hour: 12, minute: 45, now: now, calendar: utc)
        #expect(p.arriveBy == utcDate(day: 15, hour: 12, minute: 45))
        p.setArriveBy(hour: 12, minute: 0, now: now, calendar: utc)
        #expect(p.arriveBy == utcDate(day: 15, hour: 12, minute: 0))  // 30 s ago still counts as today
        p.setArriveBy(hour: 11, minute: 59, now: now, calendar: utc)
        #expect(p.arriveBy == utcDate(day: 16, hour: 11, minute: 59))  // already past: tomorrow
    }

    @Test func canStartNeedsDestinationTimeAndLocation() {
        var p = WalkPlanner()
        #expect(!p.canStart(hasLocation: true))
        _ = p.choose(park, from: origin, now: now)
        #expect(p.canStart(hasLocation: true))
        #expect(!p.canStart(hasLocation: false))
    }

    @Test func originFoundCompletesAPlanMadeWithoutALocation() {
        var p = WalkPlanner()
        _ = p.choose(park, from: nil, now: now)
        let later = now + 5
        let id = p.originFound(origin, now: later)
        let crow = Geo.haversineM(origin, park.coordinate)
        #expect(id != nil)
        #expect(p.plannedDistanceM == crow)
        #expect(!p.plannedFromRoute)
        #expect(p.arriveBy == WalkPlanner.defaultArriveBy(distanceM: crow, now: later))
        p.routeResolved(planID: id!, distanceM: 900, now: later + 1)
        #expect(p.plannedFromRoute)
        #expect(p.plannedDistanceM == 900)
    }

    @Test func originFoundKeepsAnEditedTime() {
        var p = WalkPlanner()
        _ = p.choose(park, from: nil, now: now)
        p.bump(minutes: 1, now: now)
        let edited = p.arriveBy
        let id = p.originFound(origin, now: now + 5)
        #expect(id != nil)
        #expect(p.plannedDistanceM == Geo.haversineM(origin, park.coordinate))
        #expect(p.arriveBy == edited)
        p.routeResolved(planID: id!, distanceM: 900, now: now + 6)
        #expect(!p.plannedFromRoute)  // an edited time keeps the straight-line plan, as for any edited plan
    }

    @Test func originFoundOnlyCompletesAPlanWithoutADistance() {
        var empty = WalkPlanner()
        let none = empty.originFound(origin, now: now)
        #expect(none == nil)
        #expect(empty == WalkPlanner())
        var planned = WalkPlanner()
        _ = planned.choose(park, from: origin, now: now)
        let before = planned
        let again = planned.originFound(LatLon(lat: 40.75, lon: -73.99), now: now + 5)
        #expect(again == nil)
        #expect(planned == before)
    }

    @Test func beginSessionRemeasuresAStraightLinePlanFromTheStartPoint() {
        let start = Geo.destinationPoint(from: park.coordinate, bearingDeg: 180, distanceM: 300)
        // Picked before the first fix: the 1200 m placeholder must not become the start distance.
        var early = WalkPlanner()
        _ = early.choose(park, from: nil, now: now)
        let s1 = early.beginSession(from: start, now: now + 10)!
        #expect(abs(s1.startDistanceM - 300) < 1e-6)
        #expect(!s1.routed)
        #expect(s1.start == start)
        #expect(s1.arriveBy == early.arriveBy)
        // Picked about 515 m away, started 300 m away: measured from where Start was pressed.
        var moved = WalkPlanner()
        _ = moved.choose(park, from: origin, now: now)
        let s2 = moved.beginSession(from: start, now: now + 10)!
        #expect(s2.startDistanceM == Geo.haversineM(start, park.coordinate))
    }

    @Test func beginSessionKeepsARoutedPlansDistance() {
        #expect(WalkPlanner().beginSession(from: origin, now: now) == nil)  // nothing planned yet
        var p = WalkPlanner()
        let id = p.choose(park, from: origin, now: now)!
        p.routeResolved(planID: id, distanceM: 1300, now: now)
        let start = Geo.destinationPoint(from: park.coordinate, bearingDeg: 180, distanceM: 300)
        let s = p.beginSession(from: start, now: now + 10)!
        #expect(s.startDistanceM == 1300)
        #expect(s.routed)
        #expect(s.start == start)
    }
}
