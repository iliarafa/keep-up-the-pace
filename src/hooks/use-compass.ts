import { useCallback, useEffect, useRef, useState } from "react";
import { smoothBearing } from "@/lib/geo";

type OrientationEvent = DeviceOrientationEvent & {
  webkitCompassHeading?: number | null;
  webkitCompassAccuracy?: number | null;
};

type OrientationCtor = {
  requestPermission?: () => Promise<"granted" | "denied">;
};

function compassNeedsGesture() {
  if (typeof window === "undefined" || typeof DeviceOrientationEvent === "undefined") return false;
  const ctor = DeviceOrientationEvent as unknown as OrientationCtor;
  return typeof ctor.requestPermission === "function";
}

function readHeading(event: OrientationEvent): number | null {
  const webkit = event.webkitCompassHeading;
  if (typeof webkit === "number" && Number.isFinite(webkit)) {
    if (typeof event.webkitCompassAccuracy === "number" && event.webkitCompassAccuracy < 0) return null;
    return (webkit + 360) % 360;
  }
  if (event.absolute === true && typeof event.alpha === "number" && Number.isFinite(event.alpha)) {
    return (360 - event.alpha) % 360;
  }
  return null;
}

export function useCompass(active: boolean) {
  const [deviceHeading, setDeviceHeading] = useState<number | null>(null);
  const [granted, setGranted] = useState(false);
  const [needsGesture, setNeedsGesture] = useState(false);
  const hold = useRef<number | null>(null);

  useEffect(() => {
    setNeedsGesture(compassNeedsGesture());
  }, []);

  const request = useCallback(() => {
    if (typeof window === "undefined" || typeof DeviceOrientationEvent === "undefined") {
      return Promise.resolve(false);
    }
    const ctor = DeviceOrientationEvent as unknown as OrientationCtor;
    if (typeof ctor.requestPermission !== "function") {
      setGranted(true);
      setNeedsGesture(false);
      return Promise.resolve(true);
    }
    return ctor
      .requestPermission()
      .then((result) => {
        const ok = result === "granted";
        setGranted(ok);
        setNeedsGesture(!ok);
        return ok;
      })
      .catch(() => {
        setNeedsGesture(true);
        return false;
      });
  }, []);

  useEffect(() => {
    if (!active) {
      hold.current = null;
      setDeviceHeading(null);
      return;
    }
    if (compassNeedsGesture() && !granted) return;

    const onOrientation = (event: Event) => {
      const raw = readHeading(event as OrientationEvent);
      if (raw == null) return;
      const next = smoothBearing(hold.current, raw);
      if (next === hold.current) return;
      hold.current = next;
      setDeviceHeading(next);
    };

    window.addEventListener("deviceorientation", onOrientation);
    window.addEventListener("deviceorientationabsolute", onOrientation);
    return () => {
      window.removeEventListener("deviceorientation", onOrientation);
      window.removeEventListener("deviceorientationabsolute", onOrientation);
    };
  }, [active, granted]);

  return {
    deviceHeading,
    prompt: active && needsGesture && !granted,
    request,
  };
}
