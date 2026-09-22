import { useCallback, useEffect, useRef, useState } from "react";
import type { GpsFix } from "@/lib/pace";

export type GeoStatus = "idle" | "requesting" | "live" | "denied" | "unavailable";

const WATCH_OPTIONS: PositionOptions = {
  enableHighAccuracy: true,
  maximumAge: 1000,
  timeout: 12000,
};

function toFix(pos: GeolocationPosition, last: GpsFix | null): GpsFix {
  const { coords } = pos;
  let speed = coords.speed;
  if ((speed == null || speed < 0) && last) {
    const dt = (pos.timestamp - last.timestamp) / 1000;
    if (dt > 0.4) {
      const dLat = coords.latitude - last.lat;
      const dLon = coords.longitude - last.lon;
      const m =
        Math.sqrt(dLat * dLat + dLon * dLon) * 111_320 * Math.cos((coords.latitude * Math.PI) / 180);
      speed = Math.max(0, m / dt);
    }
  }
  const next: GpsFix = {
    lat: coords.latitude,
    lon: coords.longitude,
    speedMps: speed == null || speed < 0 ? last?.speedMps ?? null : speed,
    accuracyM: coords.accuracy ?? null,
    timestamp: pos.timestamp,
  };
  if (last && next.speedMps != null && last.speedMps != null) {
    next.speedMps = last.speedMps * 0.65 + next.speedMps * 0.35;
  }
  return next;
}

export function useGeolocation(enabled: boolean) {
  const [status, setStatus] = useState<GeoStatus>("idle");
  const [fix, setFix] = useState<GpsFix | null>(null);
  const [error, setError] = useState<string | null>(null);
  const lastRef = useRef<GpsFix | null>(null);
  const watchRef = useRef<number | null>(null);

  const stop = useCallback(() => {
    if (watchRef.current != null && typeof navigator !== "undefined") {
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
    setStatus("requesting");
    setError(null);
    stop();
    watchRef.current = navigator.geolocation.watchPosition(
      (pos) => {
        const next = toFix(pos, lastRef.current);
        lastRef.current = next;
        setFix(next);
        setStatus("live");
      },
      (err) => {
        if (err.code === err.PERMISSION_DENIED) {
          setStatus("denied");
          setError("Location permission denied.");
        } else {
          setStatus("unavailable");
          setError(err.message || "Could not read GPS.");
        }
      },
      WATCH_OPTIONS,
    );
  }, [stop]);

  useEffect(() => {
    if (!enabled) {
      stop();
      return;
    }
    start();
    return stop;
  }, [enabled, start, stop]);

  return { status, fix, error, start, stop };
}
