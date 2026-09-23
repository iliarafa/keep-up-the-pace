// Golden vectors from the web app's TypeScript, so the Swift port can be checked against it.
// Run from the repo root:
//   node --experimental-strip-types --no-warnings ios/PaceKit/Scripts/make-golden.mjs > ios/PaceKit/Tests/PaceKitTests/Fixtures/golden.json
import * as geo from "../../../src/lib/geo.ts";
import * as fmt from "../../../src/lib/format.ts";

let seed = 20260922;
function rand() {
  seed = (seed * 16807) % 2147483647;
  return seed / 2147483647;
}
const between = (lo, hi) => lo + (hi - lo) * rand();
const times = (n, f) => Array.from({ length: n }, f);
const point = () => ({ lat: between(-60, 60), lon: between(-179, 179) });
const near = (p, d) => ({ lat: p.lat + between(-d, d), lon: p.lon + between(-d, d) });
const UNITS = ["imperial", "metric"];

function scheduleCase() {
  const startAt = Math.round(between(1.7e12, 1.9e12));
  const budgetMs = Math.round(between(60, 3600)) * 1000;
  const startDistanceM = between(50, 5000);
  const now = startAt + Math.round(between(-10_000, budgetMs * 1.3));
  const remainingM = between(0, startDistanceM * 1.2);
  return { startDistanceM, remainingM, startAt, arriveBy: startAt + budgetMs, now };
}

const scheduleInputs = [
  ...times(80, scheduleCase),
  { startDistanceM: 1000, remainingM: 500, startAt: 1.8e12, arriveBy: 1.8e12, now: 1.8e12 + 60_000 },
  { startDistanceM: 0, remainingM: 0, startAt: 1.8e12, arriveBy: 1.8e12 + 600_000, now: 1.8e12 + 60_000 },
  { startDistanceM: 1000, remainingM: 1000, startAt: 1.8e12, arriveBy: 1.8e12 + 600_000, now: 1.8e12 - 5_000 },
];

const golden = {
  haversine: times(60, () => {
    const a = point();
    const b = rand() < 0.7 ? near(a, 0.05) : point();
    return { a, b, out: geo.haversineM(a, b) };
  }),
  bearing: times(60, () => {
    const from = point();
    const to = near(from, 0.05);
    return { from, to, out: geo.bearingDeg(from, to) };
  }),
  destinationPoint: times(60, () => {
    const from = point();
    const bearing = between(0, 360);
    const dist = between(0, 5000);
    return { from, bearing, dist, out: geo.destinationPoint(from, bearing, dist) };
  }),
  moveTowards: [
    ...times(40, () => {
      const from = point();
      const to = near(from, 0.01);
      const dist = between(0, 2000);
      return { from, to, dist, out: geo.moveTowards(from, to, dist) };
    }),
    { from: { lat: 40, lon: -73 }, to: { lat: 40, lon: -73 }, dist: 5, out: { lat: 40, lon: -73 } },
  ],
  cardinal: [0, 22.4, 22.5, 44.9, 67.5, 90, 157.5, 180, 202.5, 270, 337.4, 337.5, 359.9, ...times(30, () => between(0, 360))].map(
    (deg) => ({ deg, out: geo.cardinal(deg) }),
  ),
  walkEstimateMs: [
    { dist: 0, pace: 1.34 },
    { dist: -5, pace: 1.34 },
    { dist: 80, pace: 1.34 },
    { dist: 1200, pace: 1.34 },
    ...times(20, () => ({ dist: between(1, 10_000), pace: rand() < 0.5 ? 1.34 : 0.85 })),
  ].map(({ dist, pace }) => ({ dist, pace, out: geo.walkEstimateMs(dist, pace) })),
  roundUpToMinute: [1_790_000_040_000, 1_790_000_040_001, 1_790_000_099_999, ...times(20, () => Math.round(between(1.7e12, 1.9e12)))].map(
    (ms) => ({ ms, out: geo.roundUpToMinute(ms) }),
  ),
  scheduleDelta: scheduleInputs.map((c) => ({ ...c, out: geo.scheduleDeltaSec(c) })),
  speed: [-1, 0, 0.1, 0.149, 0.15, 0.25, 1.34, 1.72, 2.5, ...times(30, () => between(0, 5))].flatMap((mps) =>
    UNITS.map((units) => ({ mps, units, ...fmt.formatSpeed(mps, units) })),
  ),
  distance: [-1, 0, 100, 274.3, 274.32, 279.9, 280, 999, 1609.344, 15999, 16093.44, ...times(40, () => between(0, 30_000))].flatMap((m) =>
    UNITS.map((units) => ({ m, units, out: fmt.formatDistance(m, units) })),
  ),
  duration: [0, -60_000, 29_000, 30_000, 89_000, 90_000, 3_599_000, 3_600_000, 3_630_000, 5_400_000, ...times(30, () => Math.round(between(0, 10_800)) * 1000)].map(
    (ms) => ({ ms, out: fmt.formatDuration(ms) }),
  ),
  delta: [0, 2.9, -2.9, 3, -3, 59.5, -59.5, 60, 3599.5, 3600, -3725.4, ...times(40, () => between(-4000, 4000))].map((sec) => ({
    sec,
    ...fmt.formatDelta(sec),
  })),
  heading: [0, 0.4, 0.5, 359.5, 360, -1, -0.5, 720.2, ...times(30, () => between(-720, 720))].map((deg) => ({
    deg,
    out: fmt.formatHeading(deg),
  })),
  toFixed5: [0.000005, 0.000015, 1.000005, 12.345675, 40.7, -73.9, 90, -90, 180, -180, ...times(60, () => between(-180, 180))].map(
    (x) => ({ x, out: x.toFixed(5) }),
  ),
};

console.log(JSON.stringify(golden, null, 2));
