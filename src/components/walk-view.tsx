import type { ReactNode } from "react";
import {
  formatClock,
  formatDelta,
  formatDistance,
  formatHeading,
  formatSpeed,
  type Units,
} from "@/lib/format";
import type { Session } from "@/lib/pace";
import { cn } from "@/lib/utils";

type Metrics = {
  remaining: number;
  heading: { deg: number; cardinal: string };
  deltaSec: number;
  arrived: boolean;
  speedMps: number;
};

type WalkViewProps = {
  session: Session;
  metrics: Metrics;
  units: Units;
  phase: "walk" | "arrived";
  onEnd: () => void;
};

export function WalkView({ session, metrics, units, phase, onEnd }: WalkViewProps) {
  const speed = formatSpeed(metrics.speedMps, units);
  const delta = formatDelta(metrics.deltaSec);
  const remaining = formatDistance(metrics.remaining, units);
  const arrived = phase === "arrived" || metrics.arrived;

  const deltaColor =
    arrived || delta.tone === "ontime"
      ? "text-ontime"
      : delta.tone === "early"
        ? "text-early"
        : "text-late";

  return (
    <main className="relative mx-auto flex min-h-dvh w-full max-w-lg flex-col px-6 pt-[max(env(safe-area-inset-top),1.25rem)] pb-[max(env(safe-area-inset-bottom),1.25rem)] select-none">
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
          <Compass bearing={arrived ? 0 : metrics.heading.deg} dim={arrived} />
          <p className="font-mono text-3xl leading-none font-medium tracking-tight tabular-nums text-fg">
            {arrived ? "—" : formatHeading(metrics.heading.deg)}
            {arrived ? null : (
              <span className="ml-2 align-baseline text-lg font-normal text-muted">
                {metrics.heading.cardinal}
              </span>
            )}
          </p>
        </div>

        <MetricLabel className="mt-8">Speed</MetricLabel>
        <p className="mt-1 font-mono text-3xl leading-none font-medium tracking-tight tabular-nums text-fg">
          {speed.value}
          <span className="ml-2 align-baseline text-lg font-normal text-muted">{speed.unit}</span>
        </p>

        <div className="mt-auto flex flex-col pb-2 pt-6">
          <MetricLabel>Delta</MetricLabel>
          <p
            aria-live="polite"
            className={cn(
              "mt-1 font-mono text-delta leading-none font-medium tracking-tight tabular-nums transition-colors duration-500",
              deltaColor,
            )}
          >
            {delta.sign}
            {delta.clock}
          </p>
          <p className={cn("mt-3 text-sm font-medium uppercase tracking-label", deltaColor)}>
            {arrived ? "you arrived" : delta.label}
          </p>
        </div>
      </section>

      {session.demo ? (
        <p className="text-center text-xs tracking-wide text-faint">Preview walk</p>
      ) : null}
    </main>
  );
}

function Compass({ bearing, dim }: { bearing: number; dim: boolean }) {
  return (
    <svg viewBox="0 0 120 120" className={cn("size-24 shrink-0", dim ? "opacity-40" : "")} aria-hidden>
      <circle cx="60" cy="60" r="54" fill="none" stroke="#2a2a2c" strokeWidth="1.5" />
      <text
        x="60"
        y="18"
        textAnchor="middle"
        fill="#8e8c86"
        fontSize="10"
        fontFamily="Instrument Sans, sans-serif"
      >
        N
      </text>
      <g style={{ transform: `rotate(${bearing}deg)`, transformOrigin: "60px 60px" }}>
        <polygon points="60,16 66,62 60,56 54,62" fill="#f3f1ec" />
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
