export type Units = "imperial" | "metric";

export function detectUnits(): Units {
  if (typeof navigator === "undefined") return "imperial";
  const loc = navigator.language || "en-US";
  return loc.startsWith("en-US") ? "imperial" : "metric";
}

export function formatSpeed(mps: number, units: Units): { value: string; unit: string } {
  if (!Number.isFinite(mps) || mps < 0.15) {
    return { value: "0.0", unit: units === "imperial" ? "mph" : "km/h" };
  }
  if (units === "imperial") {
    return { value: (mps * 2.236936).toFixed(1), unit: "mph" };
  }
  return { value: (mps * 3.6).toFixed(1), unit: "km/h" };
}

export function formatDistance(meters: number, units: Units): string {
  if (!Number.isFinite(meters) || meters < 0) return "—";
  if (units === "imperial") {
    const feet = meters * 3.28084;
    if (feet < 900) return `${Math.round(feet)} ft`;
    const miles = meters / 1609.344;
    return `${miles >= 10 ? miles.toFixed(0) : miles.toFixed(1)} mi`;
  }
  if (meters < 280) return `${Math.round(meters)} m`;
  const km = meters / 1000;
  return `${km >= 10 ? km.toFixed(0) : km.toFixed(1)} km`;
}

export function formatClock(ms: number): string {
  const d = new Date(ms);
  return d.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

export function formatDuration(ms: number): string {
  const totalMin = Math.max(0, Math.round(ms / 60_000));
  if (totalMin < 60) return `${totalMin} min`;
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  return m ? `${h} hr ${m} min` : `${h} hr`;
}

export type DeltaTone = "early" | "late" | "ontime";

export function formatDelta(sec: number): {
  sign: "+" | "−" | "";
  clock: string;
  label: string;
  tone: DeltaTone;
} {
  const abs = Math.abs(sec);
  if (!Number.isFinite(sec) || abs < 3) {
    return { sign: "", clock: "0:00", label: "on time", tone: "ontime" };
  }
  const sign = sec > 0 ? "+" : "−";
  const s = Math.round(abs);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  const clock =
    h > 0
      ? `${h}:${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`
      : `${m}:${String(r).padStart(2, "0")}`;
  return {
    sign,
    clock,
    label: sec > 0 ? "early" : "late",
    tone: sec > 0 ? "early" : "late",
  };
}

export function formatHeading(deg: number): string {
  const n = ((Math.round(deg) % 360) + 360) % 360;
  return `${String(n).padStart(3, "0")}°`;
}

export function timeInputValue(ms: number): string {
  const d = new Date(ms);
  const hh = String(d.getHours()).padStart(2, "0");
  const mm = String(d.getMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

export function parseTimeInput(value: string, now = Date.now()): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!m) return null;
  const hours = Number(m[1]);
  const minutes = Number(m[2]);
  if (hours > 23 || minutes > 59) return null;
  const d = new Date(now);
  d.setHours(hours, minutes, 0, 0);
  if (d.getTime() < now - 30_000) d.setDate(d.getDate() + 1);
  return d.getTime();
}
