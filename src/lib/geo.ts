export type LatLon = { lat: number; lon: number };

const EARTH_M = 6_371_000;

function toRad(deg: number) {
  return (deg * Math.PI) / 180;
}

function toDeg(rad: number) {
  return (rad * 180) / Math.PI;
}

export function haversineM(a: LatLon, b: LatLon): number {
  const φ1 = toRad(a.lat);
  const φ2 = toRad(b.lat);
  const Δφ = toRad(b.lat - a.lat);
  const Δλ = toRad(b.lon - a.lon);
  const s =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  return 2 * EARTH_M * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
}

export function bearingDeg(from: LatLon, to: LatLon): number {
  const φ1 = toRad(from.lat);
  const φ2 = toRad(to.lat);
  const Δλ = toRad(to.lon - from.lon);
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x =
    Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}

export function destinationPoint(from: LatLon, bearing: number, distM: number): LatLon {
  const δ = distM / EARTH_M;
  const θ = toRad(bearing);
  const φ1 = toRad(from.lat);
  const λ1 = toRad(from.lon);
  const φ2 = Math.asin(
    Math.sin(φ1) * Math.cos(δ) + Math.cos(φ1) * Math.sin(δ) * Math.cos(θ),
  );
  const λ2 =
    λ1 +
    Math.atan2(
      Math.sin(θ) * Math.sin(δ) * Math.cos(φ1),
      Math.cos(δ) - Math.sin(φ1) * Math.sin(φ2),
    );
  return { lat: toDeg(φ2), lon: ((toDeg(λ2) + 540) % 360) - 180 };
}

export function moveTowards(from: LatLon, to: LatLon, distM: number): LatLon {
  const d = haversineM(from, to);
  if (d <= distM || d === 0) return { ...to };
  return destinationPoint(from, bearingDeg(from, to), distM);
}

export function cardinal(deg: number): string {
  const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
  return dirs[Math.round(deg / 45) % 8] ?? "N";
}

/** Seconds ahead of schedule (positive = early, negative = late). */
export function scheduleDeltaSec(args: {
  startDistanceM: number;
  remainingM: number;
  startAt: number;
  arriveBy: number;
  now: number;
}): number {
  const budgetMs = args.arriveBy - args.startAt;
  if (budgetMs <= 0 || args.startDistanceM <= 0) return 0;
  const requiredMps = args.startDistanceM / (budgetMs / 1000);
  if (requiredMps <= 0) return 0;
  const elapsedSec = Math.max(0, (args.now - args.startAt) / 1000);
  const expectedCovered = requiredMps * elapsedSec;
  const actualCovered = Math.max(0, args.startDistanceM - args.remainingM);
  return (actualCovered - expectedCovered) / requiredMps;
}

export function walkEstimateMs(distanceM: number, paceMps = 1.34) {
  if (distanceM <= 0) return 0;
  return (distanceM / paceMps) * 1000;
}

export function roundUpToMinute(ms: number) {
  return Math.ceil(ms / 60_000) * 60_000;
}
