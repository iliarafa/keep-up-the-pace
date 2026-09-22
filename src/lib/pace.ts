import type { Place } from "@/data/places";
import {
  bearingDeg,
  cardinal,
  haversineM,
  scheduleDeltaSec,
  smoothBearing,
  type LatLon,
} from "./geo.ts";

export type GpsFix = LatLon & {
  speedMps: number | null;
  accuracyM: number | null;
  timestamp: number;
};

export type Session = {
  dest: Place;
  start: LatLon;
  startDistanceM: number;
  startAt: number;
  arriveBy: number;
  demo: boolean;
  routed: boolean;
};

export type WalkMetrics = {
  remaining: number;
  heading: { deg: number; cardinal: string };
  deltaSec: number;
  arrived: boolean;
  speedMps: number | null;
  gpsStale: boolean;
};

export const ARRIVE_RADIUS_M = 18;
export const ARRIVE_RADIUS_MAX_M = 32;

export type GeoErrorKind = "denied" | "timeout" | "unavailable";

/** A fresh fix survives a timeout. Permission denial never does. */
export function interpretGeoError(
  kind: GeoErrorKind,
  hasFreshFix: boolean,
): "denied" | "live" | "unavailable" {
  if (kind === "denied") return "denied";
  if (hasFreshFix) return "live";
  return "unavailable";
}

export function fixIsFresh(timestamp: number, now: number, maxAgeMs = 20_000) {
  if (!Number.isFinite(timestamp) || !Number.isFinite(now)) return false;
  const age = now - timestamp;
  // A fix can be newer than the 1s HUD clock. Don't call that stale.
  return age <= maxAgeMs && age >= -5_000;
}

export function remainingM(fix: LatLon, dest: LatLon) {
  return haversineM(fix, dest);
}

export function headingToDest(
  fix: LatLon,
  dest: LatLon,
  previousDeg: number | null = null,
  hold = true,
) {
  const raw = bearingDeg(fix, dest);
  const deg = smoothBearing(previousDeg, raw, hold && haversineM(fix, dest) < 22);
  return { deg, cardinal: cardinal(deg) };
}

/** Phone GPS is often wider than 18m. Don't require a tighter bubble than the fix, and don't arrive from down the block. */
export function arriveRadiusM(accuracyM: number | null | undefined) {
  if (accuracyM == null || !Number.isFinite(accuracyM) || accuracyM <= 0) return ARRIVE_RADIUS_M;
  return Math.min(ARRIVE_RADIUS_MAX_M, Math.max(ARRIVE_RADIUS_M, accuracyM * 0.75));
}

export function computeDelta(session: Session, remaining: number, now: number) {
  return scheduleDeltaSec({
    startDistanceM: session.startDistanceM,
    remainingM: remaining,
    startAt: session.startAt,
    arriveBy: session.arriveBy,
    now,
  });
}

export function hasArrived(remaining: number, accuracyM?: number | null) {
  return remaining <= arriveRadiusM(accuracyM);
}

/** Keep a street-route distance live between router samples by scaling the crow-flies fix. */
export function routeScale(routeM: number, crowM: number) {
  if (!Number.isFinite(routeM) || !Number.isFinite(crowM) || crowM < 25 || routeM <= 0) return null;
  const factor = routeM / crowM;
  if (factor < 0.85 || factor > 5) return null;
  return factor;
}
