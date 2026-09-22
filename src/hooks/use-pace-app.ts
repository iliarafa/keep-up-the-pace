import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Place } from "@/data/places";
import {
  destinationPoint,
  haversineM,
  moveTowards,
  roundUpToMinute,
  walkEstimateMs,
  type LatLon,
} from "@/lib/geo";
import { detectUnits, parseTimeInput, timeInputValue, type Units } from "@/lib/format";
import {
  ARRIVE_RADIUS_M,
  computeDelta,
  hasArrived,
  headingToDest,
  remainingM,
  type GpsFix,
  type Session,
} from "@/lib/pace";
import { useGeolocation } from "@/hooks/use-geolocation";
import { useNow } from "@/hooks/use-now";
import { useWakeLock } from "@/hooks/use-wake-lock";
import { walkDistanceM } from "@/lib/route";

export type Phase = "setup" | "walk" | "arrived";

const UNITS_KEY = "ktp:units";
const RECENT_KEY = "ktp:recent";

const DEMO_DEST: Place = {
  name: "Gantry Plaza State Park",
  area: "Long Island City",
  lat: 40.74551,
  lon: -73.95875,
};

function loadUnits(): Units {
  if (typeof window === "undefined") return "imperial";
  const stored = window.localStorage.getItem(UNITS_KEY);
  if (stored === "imperial" || stored === "metric") return stored;
  return detectUnits();
}

function loadRecent(): Place[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(RECENT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as Place[];
    return Array.isArray(parsed) ? parsed.slice(0, 6) : [];
  } catch {
    return [];
  }
}

function saveRecent(place: Place) {
  const next = [place, ...loadRecent().filter((p) => p.name !== place.name)].slice(0, 6);
  window.localStorage.setItem(RECENT_KEY, JSON.stringify(next));
}

function demoStartFrom(dest: Place): LatLon {
  return destinationPoint(dest, 188, 280);
}

export function usePaceApp() {
  const [phase, setPhase] = useState<Phase>("setup");
  const [units, setUnitsState] = useState<Units>("imperial");
  const [destination, setDestination] = useState<Place | null>(null);
  const [arriveBy, setArriveBy] = useState<number | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [demoFix, setDemoFix] = useState<GpsFix | null>(null);
  const [recent, setRecent] = useState<Place[]>([]);
  const [gpsWanted, setGpsWanted] = useState(true);
  const [planMeters, setPlanMeters] = useState<number | null>(null);
  const [planFromRoute, setPlanFromRoute] = useState(false);
  const [routeRemaining, setRouteRemaining] = useState<number | null>(null);
  const lockedRef = useRef(false);
  const etaTouched = useRef(false);
  const planToken = useRef(0);
  const frozenDelta = useRef<number | null>(null);
  const fixRef = useRef<GpsFix | null>(null);

  const watchingLive = gpsWanted && (phase === "setup" || Boolean(session && !session.demo));
  const geo = useGeolocation(watchingLive);
  const now = useNow(1000, phase !== "setup");
  useWakeLock(phase === "walk");

  useEffect(() => {
    setUnitsState(loadUnits());
    setRecent(loadRecent());
  }, []);

  const setUnits = useCallback((next: Units) => {
    setUnitsState(next);
    window.localStorage.setItem(UNITS_KEY, next);
  }, []);

  const origin: LatLon | null = geo.fix;

  const chooseDestination = useCallback((place: Place, from: LatLon | null = origin) => {
    setDestination(place);
    etaTouched.current = false;
    const crow = from ? haversineM(from, place) : 1200;
    setPlanFromRoute(false);
    setPlanMeters(crow);
    setArriveBy(roundUpToMinute(Date.now() + walkEstimateMs(Math.max(crow, 80))));
    if (!from) return;
    const token = ++planToken.current;
    void walkDistanceM(from, place).then((meters) => {
      if (meters == null || token !== planToken.current || etaTouched.current) return;
      setPlanFromRoute(true);
      setPlanMeters(meters);
      setArriveBy(roundUpToMinute(Date.now() + walkEstimateMs(Math.max(meters, 80))));
    });
  }, [origin]);

  const bumpArriveBy = useCallback((deltaMin: number) => {
    etaTouched.current = true;
    setArriveBy((prev) => {
      const base = prev ?? Date.now() + 15 * 60_000;
      return Math.max(Date.now() + 60_000, base + deltaMin * 60_000);
    });
  }, []);

  const setArriveByInput = useCallback((value: string) => {
    const parsed = parseTimeInput(value);
    if (!parsed) return;
    etaTouched.current = true;
    setArriveBy(parsed);
  }, []);

  const beginSession = useCallback(
    (opts: { dest: Place; start: LatLon; arriveBy: number; demo: boolean; startDistanceM?: number; routed?: boolean }) => {
      const crow = haversineM(opts.start, opts.dest);
      const startDistanceM = Math.max(opts.startDistanceM ?? crow, 30);
      const sess: Session = {
        dest: opts.dest,
        start: opts.start,
        startDistanceM,
        startAt: Date.now(),
        arriveBy: Math.max(opts.arriveBy, Date.now() + 60_000),
        demo: opts.demo,
        routed: Boolean(opts.routed),
      };
      lockedRef.current = false;
      frozenDelta.current = null;
      setRouteRemaining(opts.routed ? startDistanceM : null);
      setSession(sess);
      setDestination(opts.dest);
      setArriveBy(sess.arriveBy);
      saveRecent(opts.dest);
      setRecent(loadRecent());
      if (opts.demo) {
        setDemoFix({
          ...opts.start,
          speedMps: 1.72,
          accuracyM: 5,
          timestamp: Date.now(),
        });
        setGpsWanted(false);
      } else {
        setDemoFix(null);
        setGpsWanted(true);
      }
      setPhase("walk");
    },
    [],
  );

  const startWalking = useCallback(() => {
    if (!destination || !arriveBy) return;
    const start = geo.fix;
    if (!start) return;
    const fallback = planMeters ?? haversineM(start, destination);
    beginSession({
      dest: destination,
      start,
      arriveBy,
      demo: false,
      startDistanceM: fallback,
      routed: planFromRoute,
    });
  }, [arriveBy, beginSession, destination, geo.fix, planFromRoute, planMeters]);

  const startDemo = useCallback(() => {
    const dest = destination ?? DEMO_DEST;
    const start = demoStartFrom(dest);
    const dist = haversineM(start, dest);
    const arrive = Date.now() + walkEstimateMs(dist, 0.85);
    beginSession({ dest, start, arriveBy: arrive, demo: true });
  }, [beginSession, destination]);

  useEffect(() => {
    if (phase !== "walk" || !session?.demo) return;
    const dest = session.dest;
    const id = window.setInterval(() => {
      setDemoFix((prev) => {
        if (!prev) return prev;
        const remaining = haversineM(prev, dest);
        if (remaining <= ARRIVE_RADIUS_M) {
          return { ...prev, ...dest, speedMps: 0, timestamp: Date.now() };
        }
        const t = Date.now() / 1000;
        const speed = 1.72 + Math.sin(t / 3.2) * 0.18;
        const next = moveTowards(prev, dest, speed * 0.25);
        return {
          lat: next.lat,
          lon: next.lon,
          speedMps: speed,
          accuracyM: 5,
          timestamp: Date.now(),
        };
      });
    }, 250);
    return () => window.clearInterval(id);
  }, [phase, session]);

  const liveFix: GpsFix | null = session?.demo ? demoFix : geo.fix;
  fixRef.current = liveFix;

  useEffect(() => {
    if (phase === "setup" || !session?.routed) return;
    let stop = false;
    const pull = async () => {
      const fix = fixRef.current;
      if (!fix) return;
      const meters = await walkDistanceM(fix, session.dest);
      if (!stop && meters != null) setRouteRemaining(meters);
    };
    void pull();
    const id = window.setInterval(pull, 12_000);
    return () => {
      stop = true;
      window.clearInterval(id);
    };
  }, [phase, session]);

  const metrics = useMemo(() => {
    if (!session || !liveFix) return null;
    const crow = remainingM(liveFix, session.dest);
    const remaining = session.routed ? (routeRemaining ?? crow) : crow;
    const heading = headingToDest(liveFix, session.dest);
    const arrived = hasArrived(crow);
    const liveDelta = computeDelta(session, arrived ? 0 : remaining, now);
    if (arrived && frozenDelta.current == null) frozenDelta.current = liveDelta;
    return {
      remaining: arrived ? 0 : remaining,
      heading,
      deltaSec: arrived ? (frozenDelta.current ?? liveDelta) : liveDelta,
      arrived,
      speedMps: liveFix.speedMps ?? 0,
    };
  }, [liveFix, now, routeRemaining, session]);

  useEffect(() => {
    if (phase !== "walk" || !metrics?.arrived || lockedRef.current) return;
    lockedRef.current = true;
    setPhase("arrived");
  }, [metrics?.arrived, phase]);

  const endSession = useCallback(() => {
    setPhase("setup");
    setSession(null);
    setDemoFix(null);
    setGpsWanted(true);
    setRouteRemaining(null);
    frozenDelta.current = null;
    lockedRef.current = false;
  }, []);

  return {
    phase,
    units,
    setUnits,
    destination,
    arriveBy,
    arriveByInput: arriveBy ? timeInputValue(arriveBy) : "",
    setArriveByInput,
    bumpArriveBy,
    chooseDestination,
    origin,
    geo,
    recent,
    planMeters,
    session,
    metrics,
    startWalking,
    startDemo,
    endSession,
    canStart: Boolean(destination && arriveBy && geo.fix),
  };
}
