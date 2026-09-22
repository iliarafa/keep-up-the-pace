import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { formatDelta, formatHeading, formatSpeed } from "./format.ts";
import {
  bearingDeg,
  destinationPoint,
  resolveSpeed,
  scheduleDeltaSec,
  speedFromTrack,
} from "./geo.ts";
import {
  arriveRadiusM,
  fixIsFresh,
  hasArrived,
  headingToDest,
  interpretGeoError,
  routeScale,
} from "./pace.ts";

const start = 1_700_000_000_000;

describe("scheduleDeltaSec", () => {
  const base = {
    startDistanceM: 1000,
    startAt: start,
    arriveBy: start + 1000_000,
  };

  it("is zero when you are exactly on the required pace", () => {
    const delta = scheduleDeltaSec({ ...base, remainingM: 900, now: start + 100_000 });
    assert.ok(Math.abs(delta) < 0.001);
  });

  it("is positive when you are early and negative when you are late", () => {
    const early = scheduleDeltaSec({ ...base, remainingM: 800, now: start + 100_000 });
    const late = scheduleDeltaSec({ ...base, remainingM: 1000, now: start + 100_000 });
    assert.ok(early > 0);
    assert.ok(late < 0);
    assert.equal(Math.round(early), 100);
    assert.equal(Math.round(late), -100);
  });

  it("counts walking away as later than standing still", () => {
    const still = scheduleDeltaSec({ ...base, remainingM: 1000, now: start + 100_000 });
    const away = scheduleDeltaSec({ ...base, remainingM: 1200, now: start + 100_000 });
    assert.ok(away < still);
    assert.equal(Math.round(away), -300);
  });
});

describe("formatDelta", () => {
  it("labels a positive value early and a negative value late", () => {
    const early = formatDelta(61);
    assert.deepEqual(early, { sign: "+", clock: "1:01", label: "early", tone: "early" });
    const late = formatDelta(-47);
    assert.equal(late.sign, "−");
    assert.equal(late.clock, "0:47");
    assert.equal(late.label, "late");
    assert.equal(late.tone, "late");
  });

  it("treats a couple of seconds as on time", () => {
    assert.equal(formatDelta(2).tone, "ontime");
    assert.equal(formatDelta(-2).label, "on time");
  });
});

describe("speed", () => {
  const origin = { lat: 40.74551, lon: -73.95875, timestamp: 0, accuracyM: 5 };

  it("measures northbound speed with haversine, not a latitude cosine", () => {
    const north = destinationPoint(origin, 0, 20);
    const speed = speedFromTrack(origin, { ...north, timestamp: 5000, accuracyM: 5 });
    assert.ok(speed != null);
    assert.ok(Math.abs(speed - 4) < 0.15);
  });

  it("measures eastbound speed the same way", () => {
    const east = destinationPoint(origin, 90, 20);
    const speed = speedFromTrack(origin, { ...east, timestamp: 5000, accuracyM: 5 });
    assert.ok(speed != null);
    assert.ok(Math.abs(speed - 4) < 0.15);
  });

  it("drops jitter inside the accuracy bubble and rejects spikes", () => {
    const jitter = destinationPoint(origin, 45, 3);
    assert.equal(speedFromTrack(origin, { ...jitter, timestamp: 1000, accuracyM: 20 }), 0);
    const spike = destinationPoint(origin, 90, 40);
    assert.equal(speedFromTrack(origin, { ...spike, timestamp: 1000, accuracyM: 5 }), null);
  });

  it("trusts a moving track when the platform speed is stuck at zero", () => {
    const speed = resolveSpeed({ reported: 0, derived: 1.4, previous: 1.2 });
    assert.ok(speed != null && speed > 1);
  });
});

describe("heading and arrival", () => {
  it("aims the demo start back at the destination on a north bearing", () => {
    const dest = { lat: 40.74551, lon: -73.95875 };
    const from = destinationPoint(dest, 188, 280);
    const heading = headingToDest(from, dest);
    assert.ok(Math.abs(heading.deg - 8) < 0.5);
    assert.equal(heading.cardinal, "N");
    assert.equal(formatHeading(heading.deg), "008°");
    assert.ok(Math.abs(bearingDeg(from, dest) - 8) < 0.5);
  });

  it("holds a trusted bearing once you are on top of the pin", () => {
    const dest = { lat: 40.74551, lon: -73.95875 };
    const near = destinationPoint(dest, 90, 10);
    assert.equal(headingToDest(near, dest, 8, true).deg, 8);
    assert.notEqual(headingToDest(near, dest, 8, false).deg, 8);
  });

  it("widens the arrival bubble with GPS accuracy and then caps it", () => {
    assert.equal(arriveRadiusM(5), 18);
    assert.equal(arriveRadiusM(40), 30);
    assert.equal(arriveRadiusM(80), 32);
    assert.equal(hasArrived(20, 5), false);
    assert.equal(hasArrived(20, 40), true);
  });
});

describe("gps errors and route scale", () => {
  it("keeps a fresh fix through a timeout and never through a denial", () => {
    assert.equal(interpretGeoError("timeout", true), "live");
    assert.equal(interpretGeoError("timeout", false), "unavailable");
    assert.equal(interpretGeoError("denied", true), "denied");
    assert.equal(fixIsFresh(1_000, 1_000 + 20_000), true);
    assert.equal(fixIsFresh(1_000, 1_000 + 20_001), false);
  });

  it("scales street distance onto the live crow-flies fix", () => {
    assert.equal(routeScale(1400, 1000), 1.4);
    assert.equal(routeScale(100, 10), null);
    assert.equal(routeScale(9000, 1000), null);
  });
});

describe("formatSpeed", () => {
  it("shows an em dash until a sample exists and zero when stopped", () => {
    assert.equal(formatSpeed(null, "imperial").value, "—");
    assert.equal(formatSpeed(0, "imperial").value, "0.0");
    assert.equal(formatSpeed(1.72, "imperial").value, "3.8");
  });
});
