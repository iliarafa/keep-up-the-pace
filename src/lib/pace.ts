import type { Place } from "@/data/places";
import {
  bearingDeg,
  cardinal,
  haversineM,
  scheduleDeltaSec,
  type LatLon,
} from "@/lib/geo";

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

export const ARRIVE_RADIUS_M = 18;

export function remainingM(fix: LatLon, dest: LatLon) {
  return haversineM(fix, dest);
}

export function headingToDest(fix: LatLon, dest: LatLon) {
  const deg = bearingDeg(fix, dest);
  return { deg, cardinal: cardinal(deg) };
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

export function hasArrived(remaining: number) {
  return remaining <= ARRIVE_RADIUS_M;
}
