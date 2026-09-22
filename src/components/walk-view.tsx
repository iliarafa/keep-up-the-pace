import type { ReactNode } from "react";
import {
  formatClock,
  formatDelta,
  formatDistance,
  formatHeading,
  formatSpeed,
  type Units,
} from "@/lib/format";
import type { Session, WalkMetrics } from "@/lib/pace";
import type { GeoStatus } from "@/hooks/use-geolocation";
import { cn } from "@/lib/utils";

type WalkViewProps = {
  session: Session;
  metrics: WalkMetrics | null;
  units: Units;
  phase: "walk" | "arrived";
  gpsStatus: GeoStatus;
  deviceHeading: number | null;
  compassPrompt: boolean;
  onEnableCompass: () => void;
  onEnd: () => void;
};

export function WalkView({
  session,
  metrics,
  units,
  phase,
  gpsStatus,
  deviceHeading,
  compassPrompt,
  onEnableCompass,
  onEnd,
}: WalkViewProps) {
  const arrived = phase === "arrived" || Boolean(metrics?.arrived);
  const speed = formatSpeed(metrics?.speedMps ?? null, units);
  const delta = metrics ? formatDelta(metrics.deltaSec) : null;
  const remaining = metrics ? formatDistance(metrics.remaining, units) : "—";
  const longDelta = Boolean(delta && delta.clock.split(":").length > 2);

  const deltaColor =
    !delta || delta.tone === "ontime"
      ? "text-ontime"
      : delta.tone === "early"
        ? "text-early"
        : "text-late";

  const deltaLabel = !delta
    ? "waiting for gps"
    : arrived
      ? delta.tone === "ontime"
        ? "you arrived"
        : `arrived ${delta.label}`
      : delta.label;

  const gpsNote = session.demo
    ? null
    : gpsStatus === "denied"
      ? "Location is off. Delta is holding the last fix."
      : gpsStatus === "unavailable" || metrics?.gpsStale
        ? "GPS signal is weak."
        : gpsStatus === "requesting" || !metrics
          ? "Finding GPS…"
          : null;

  return (
    <main className="relative mx-auto flex min-h-dvh w-full max-w-lg flex-col px-[max(env(safe-area-inset-left),1.5rem)] pr-[max(env(safe-area-inset-right),1.5rem)] pt-[max(env(safe-area-inset-top),1.25rem)] pb-[max(env(safe-area-inset-bottom),1.25rem)] select-none">
      <header className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <p className="text-xs font-medium uppercase tracking-label text-muted">Keep the Pace</p>
          <h1 className="mt-1 truncate text-xl font-medium tracking-tight text-fg">
            {session.dest.name}
          </h1>
          <p className="mt-0.5 text-sm text-muted">
            {arrived ? "Arrived" : `${remaining} left · ${formatClock(session.arriveBy)}`}
          </p>
        </div>
        <button
          type="button"
          onClick={onEnd}
          className="mt-1 min-h-11 rounded-sm px-3 py-2 text-sm font-medium text-muted transition-colors duration-150 hover:text-fg"
        >
          End
        </button>
      </header>

      <section className="mt-8 flex flex-1 flex-col">
        <MetricLabel>Heading</MetricLabel>
        <div className="mt-3 flex items-center gap-5">
          <Compass
            bearing={arrived || !metrics ? 0 : metrics.heading.deg}
            deviceHeading={arrived ? null : deviceHeading}
            dim={arrived || !metrics}
          />
          <p
            className="font-mono text-metric leading-none font-medium tracking-tight tabular-nums text-fg"
            aria-label={
              arrived || !metrics
                ? "Heading unavailable"
                : `Heading ${formatHeading(metrics.heading.deg)} ${metrics.heading.cardinal}, bearing to destination`
            }
          >
            {arrived || !metrics ? "—" : formatHeading(metrics.heading.deg)}
            {arrived || !metrics ? null : (
              <span className="ml-2 align-baseline text-lg font-normal text-muted">
                {metrics.heading.cardinal}
              </span>
            )}
          </p>
        </div>
        {compassPrompt ? (
          <button
            type="button"
            onClick={onEnableCompass}
            className="mt-3 min-h-11 self-start text-sm font-medium text-muted"
          >
            Enable compass
          </button>
        ) : null}

        <MetricLabel className="mt-8">Speed</MetricLabel>
        <p
          className="mt-1 font-mono text-metric leading-none font-medium tracking-tight tabular-nums text-fg"
          aria-label={`Speed ${speed.value} ${speed.unit}`}
        >
          {speed.value}
          <span className="ml-2 align-baseline text-lg font-normal text-muted">{speed.unit}</span>
        </p>

        <div className="mt-auto flex flex-col pb-2 pt-6">
          <MetricLabel>Delta</MetricLabel>
          <p
            aria-live="polite"
            aria-label={delta ? `${delta.sign}${delta.clock} ${deltaLabel}` : "Delta unavailable"}
            className={cn(
              "mt-1 max-w-full font-mono leading-none font-medium tracking-tight whitespace-nowrap tabular-nums transition-colors duration-500",
              longDelta ? "text-delta-long" : "text-delta",
              deltaColor,
            )}
          >
            {delta ? (
              <>
                {delta.sign}
                {delta.clock}
              </>
            ) : (
              "—"
            )}
          </p>
          <p className={cn("mt-3 text-sm font-medium uppercase tracking-label", deltaColor)}>
            {deltaLabel}
          </p>
        </div>
      </section>

      {gpsNote ? <p className="text-center text-xs tracking-wide text-late">{gpsNote}</p> : null}
      {session.demo ? (
        <p className="text-center text-xs tracking-wide text-faint">Preview walk</p>
      ) : null}
    </main>
  );
}

function Compass({
  bearing,
  deviceHeading,
  dim,
}: {
  bearing: number;
  deviceHeading: number | null;
  dim: boolean;
}) {
  const rose = deviceHeading == null ? 0 : -deviceHeading;
  const needle =
    deviceHeading == null ? bearing : (bearing - deviceHeading + 360) % 360;
  return (
    <svg
      viewBox="0 0 120 120"
      className={cn("size-24 shrink-0", dim ? "opacity-40" : "")}
      aria-hidden
    >
      <circle cx="60" cy="60" r="54" fill="none" stroke="var(--color-line)" strokeWidth="1.5" />
      <g transform={`rotate(${rose} 60 60)`}>
        <text
          x="60"
          y="18"
          textAnchor="middle"
          fill="var(--color-muted)"
          fontSize="10"
          fontFamily="Instrument Sans, sans-serif"
        >
          N
        </text>
      </g>
      <g transform={`rotate(${needle} 60 60)`}>
        <polygon points="60,16 66,62 60,56 54,62" fill="var(--color-fg)" />
      </g>
    </svg>
  );
}

function MetricLabel({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <p className={cn("text-xs font-medium uppercase tracking-label text-muted", className)}>
      {children}
    </p>
  );
}
