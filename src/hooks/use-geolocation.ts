import { useCallback, useEffect, useRef, useState } from "react";
import { resolveSpeed, speedFromTrack } from "@/lib/geo";
import { fixIsFresh, interpretGeoError, type GeoErrorKind, type GpsFix } from "@/lib/pace";

export type GeoStatus = "idle" | "requesting" | "live" | "denied" | "unavailable";

const WATCH_OPTIONS: PositionOptions = {
  enableHighAccuracy: true,
  maximumAge: 1500,
  timeout: 20000,
};

function reportedSpeed(speed: number | null): number | null {
  if (speed == null || !Number.isFinite(speed) || speed < 0) return null;
  return speed;
}

function toFix(pos: GeolocationPosition, last: GpsFix | null): GpsFix {
  const { coords } = pos;
  const derived = last
    ? speedFromTrack(
        {
          lat: last.lat,
          lon: last.lon,
          timestamp: last.timestamp,
          accuracyM: last.accuracyM,
        },
        {
          lat: coords.latitude,
          lon: coords.longitude,
          timestamp: pos.timestamp,
          accuracyM: coords.accuracy,
        },
      )
    : null;
  return {
    lat: coords.latitude,
    lon: coords.longitude,
    speedMps: resolveSpeed({
      reported: reportedSpeed(coords.speed),
      derived,
      previous: last?.speedMps ?? null,
    }),
    accuracyM: Number.isFinite(coords.accuracy) ? coords.accuracy : null,
    timestamp: pos.timestamp,
  };
}

function errorKind(err: GeolocationPositionError): GeoErrorKind {
  if (err.code === err.PERMISSION_DENIED) return "denied";
  if (err.code === err.TIMEOUT) return "timeout";
  return "unavailable";
}

export function useGeolocation(enabled: boolean) {
  const [status, setStatus] = useState<GeoStatus>("idle");
  const [fix, setFix] = useState<GpsFix | null>(null);
  const [error, setError] = useState<string | null>(null);
  const lastRef = useRef<GpsFix | null>(null);
  const watchRef = useRef<number | null>(null);
  const restartRef = useRef<number | null>(null);
  const enabledRef = useRef(enabled);
  enabledRef.current = enabled;

  const stop = useCallback(() => {
    if (typeof window !== "undefined" && restartRef.current != null) {
      window.clearTimeout(restartRef.current);
      restartRef.current = null;
    }
    if (watchRef.current != null && typeof navigator !== "undefined" && navigator.geolocation) {
      navigator.geolocation.clearWatch(watchRef.current);
      watchRef.current = null;
    }
  }, []);

  const start = useCallback(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setStatus("unavailable");
      setError("Location is not available in this browser.");
      return;
    }
    const fresh = lastRef.current != null && fixIsFresh(lastRef.current.timestamp, Date.now());
    setStatus((current) => (current === "live" && fresh ? "live" : "requesting"));
    setError(null);
    stop();

    const onPosition = (pos: GeolocationPosition) => {
      const next = toFix(pos, lastRef.current);
      lastRef.current = next;
      setFix(next);
      setStatus("live");
      setError(null);
    };

    const onError = (err: GeolocationPositionError) => {
      const kind = errorKind(err);
      const hasFresh = lastRef.current != null && fixIsFresh(lastRef.current.timestamp, Date.now());
      const next = interpretGeoError(kind, hasFresh);
      const scheduleRestart = () => {
        if (kind !== "timeout" || !enabledRef.current || restartRef.current != null) return;
        const stamp = lastRef.current?.timestamp ?? 0;
        restartRef.current = window.setTimeout(() => {
          restartRef.current = null;
          if (!enabledRef.current) return;
          const stillStuck = !lastRef.current || lastRef.current.timestamp === stamp;
          if (stillStuck) start();
        }, 2500);
      };
      if (next === "denied") {
        setStatus("denied");
        setError("Location permission denied.");
        return;
      }
      if (next === "live") {
        setStatus("live");
        scheduleRestart();
        return;
      }
      setStatus("unavailable");
      setError(kind === "timeout" ? "GPS is taking too long." : err.message || "Could not read GPS.");
      scheduleRestart();
    };

    watchRef.current = navigator.geolocation.watchPosition(onPosition, onError, WATCH_OPTIONS);
  }, [stop]);

  useEffect(() => {
    if (!enabled) {
      stop();
      setStatus((current) => (current === "denied" || current === "unavailable" ? current : "idle"));
      return;
    }
    start();
    return stop;
  }, [enabled, start, stop]);

  useEffect(() => {
    if (!enabled || typeof navigator === "undefined" || !navigator.permissions?.query) return;
    let permission: PermissionStatus | null = null;
    let cancelled = false;
    navigator.permissions
      .query({ name: "geolocation" })
      .then((perm) => {
        if (cancelled) return;
        permission = perm;
        const apply = () => {
          if (perm.state === "denied") {
            setStatus("denied");
            setError("Location permission denied.");
            return;
          }
          if (perm.state === "granted") start();
        };
        if (perm.state === "denied") apply();
        perm.onchange = apply;
      })
      .catch(() => {});
    return () => {
      cancelled = true;
      if (permission) permission.onchange = null;
    };
  }, [enabled, start]);

  useEffect(() => {
    if (!enabled || typeof document === "undefined") return;
    const onVisible = () => {
      if (document.visibilityState === "visible") start();
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [enabled, start]);

  return { status, fix, error, start, stop };
}
