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
  return dirs[Math.round(((deg % 360) + 360) % 360 / 45) % 8] ?? "N";
}

/**
 * Ease a compass bearing. `hold` keeps the last good aim when the fix is too
 * close for a stable direction (GPS noise spins the needle at the door).
 */
export function smoothBearing(prev: number | null, next: number, hold = false): number {
  if (!Number.isFinite(next)) return prev ?? 0;
  const norm = ((next % 360) + 360) % 360;
  if (prev == null || !Number.isFinite(prev)) return norm;
  if (hold) return prev;
  const delta = ((norm - prev + 540) % 360) - 180;
  if (Math.abs(delta) < 3) return prev;
  return (prev + delta * 0.45 + 360) % 360;
}

/** Meters / second between two fixes. 0 is stationary; null is an unusable sample. */
export function speedFromTrack(
  prev: LatLon & { timestamp: number; accuracyM?: number | null },
  next: LatLon & { timestamp: number; accuracyM?: number | null },
): number | null {
  const dt = (next.timestamp - prev.timestamp) / 1000;
  if (!Number.isFinite(dt) || dt < 0.4 || dt > 20) return null;
  const dist = haversineM(prev, next);
  if (!Number.isFinite(dist)) return null;
  const noise = Math.max(prev.accuracyM ?? 12, next.accuracyM ?? 12, 8);
  if (dist < Math.min(noise * 0.55, 14)) return 0;
  const speed = dist / dt;
  if (speed > 8) return null;
  return speed;
}

/**
 * Prefer the platform speed when it exists. iPhone Safari often reports null,
 * and sometimes sticks at 0 while the fix is clearly moving.
 */
export function resolveSpeed(args: {
  reported: number | null;
  derived: number | null;
  previous: number | null;
}): number | null {
  const reported =
    args.reported != null && args.reported >= 0 && args.reported <= 8 ? args.reported : null;
  let next: number | null = null;
  if (reported != null && args.derived != null && reported < 0.3 && args.derived >= 0.7) {
    next = args.derived;
  } else if (reported != null) {
    next = reported;
  } else {
    next = args.derived;
  }
  if (next == null) return args.previous;
  if (args.previous == null) return next < 0.15 ? 0 : next;
  const blended = next === 0 ? args.previous * 0.4 : args.previous * 0.55 + next * 0.45;
  return blended < 0.15 ? 0 : blended;
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
  const now = Math.max(args.now, args.startAt);
  const timeLeftSec = (args.arriveBy - now) / 1000;
  const remaining = Math.max(0, args.remainingM);
  return timeLeftSec - remaining / requiredMps;
}

export function walkEstimateMs(distanceM: number, paceMps = 1.34) {
  if (distanceM <= 0) return 0;
  return (distanceM / paceMps) * 1000;
}

export function roundUpToMinute(ms: number) {
  return Math.ceil(ms / 60_000) * 60_000;
}
