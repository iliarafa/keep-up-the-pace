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

    @Test func noOriginPlansFallbackDistanceAndNoRoute() {
        var p = WalkPlanner()
        #expect(p.choose(park, from: nil, now: now) == nil)
        #expect(p.plannedDistanceM == 1200)
        #expect(p.arriveBy == Geo.roundUpToMinute(now + 1200 / 1.34))
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
}
