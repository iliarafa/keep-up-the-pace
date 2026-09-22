import { MapPin, Navigation, Search } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { searchGazetteer, type Place } from "@/data/places";
import { searchDestinations, suggestionsFor } from "@/lib/geocode";
import { formatClock, formatDistance, formatDuration, type Units } from "@/lib/format";
import { haversineM, walkEstimateMs, type LatLon } from "@/lib/geo";
import type { GeoStatus } from "@/hooks/use-geolocation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

type SetupViewProps = {
  units: Units;
  setUnits: (u: Units) => void;
  destination: Place | null;
  origin: LatLon | null;
  geoStatus: GeoStatus;
  geoError: string | null;
  requestGps: () => void;
  arriveBy: number | null;
  arriveByInput: string;
  setArriveByInput: (value: string) => void;
  bumpArriveBy: (deltaMin: number) => void;
  chooseDestination: (place: Place) => void;
  recent: Place[];
  planMeters: number | null;
  canStart: boolean;
  onStart: () => void;
  onDemo: () => void;
};

export function SetupView(props: SetupViewProps) {
  const {
    units,
    setUnits,
    destination,
    origin,
    geoStatus,
    geoError,
    requestGps,
    arriveBy,
    arriveByInput,
    setArriveByInput,
    bumpArriveBy,
    chooseDestination,
    recent,
    planMeters,
    canStart,
    onStart,
    onDemo,
  } = props;

  const searchId = useId();
  const [query, setQuery] = useState("");
  const [hits, setHits] = useState<Place[]>([]);
  const [searching, setSearching] = useState(false);
  const requestRef = useRef(0);

  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
      setHits([]);
      setSearching(false);
      return;
    }
    const local = searchGazetteer(q, origin);
    setHits(local);
    setSearching(local.length === 0);
    const id = ++requestRef.current;
    const timer = window.setTimeout(() => {
      void searchDestinations(q, origin)
        .then((results) => {
          if (requestRef.current !== id) return;
          setHits(results.length ? results : local);
          setSearching(false);
        })
        .catch(() => {
          if (requestRef.current !== id) return;
          setHits(local);
          setSearching(false);
        });
    }, 220);
    return () => window.clearTimeout(timer);
  }, [origin, query]);

  const showChips = query.trim().length < 2 && !destination;
  const chips = showChips ? (recent.length ? recent.slice(0, 3) : suggestionsFor(origin)) : [];
  const walkMs = destination && origin && planMeters != null ? walkEstimateMs(planMeters) : null;

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-5 pt-[max(env(safe-area-inset-top),1.5rem)]">
      <header className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-medium uppercase tracking-label text-muted">Keep the Pace</p>
          <h1 className="mt-2 font-sans text-3xl font-medium leading-tight tracking-tight text-fg">
            Arrive on time.
          </h1>
        </div>
        <button
          type="button"
          onClick={() => setUnits(units === "imperial" ? "metric" : "imperial")}
          className="mt-1 rounded-sm px-2 py-1 text-xs font-medium tracking-wide text-muted transition-colors duration-150 hover:text-fg"
          aria-label="Toggle units"
        >
          {units === "imperial" ? "mph" : "km/h"}
        </button>
      </header>

      <label htmlFor={searchId} className="mt-8 text-xs font-medium uppercase tracking-label text-muted">
        Destination
      </label>
      <div className="relative mt-2">
        <Search className="pointer-events-none absolute top-1/2 left-4 size-4 -translate-y-1/2 text-faint" />
        <Input
          id={searchId}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
          }}
          placeholder="Park, plaza, street…"
          autoComplete="off"
          autoCorrect="off"
          spellCheck={false}
          className="pl-11"
        />
      </div>

      <div className="mt-3 flex flex-col gap-1">
        {searching ? <p className="px-1 py-2 text-sm text-muted">Searching…</p> : null}
        {hits.map((place) => (
          <PlaceRow
            key={`${place.name}-${place.lat}`}
            place={place}
            origin={origin}
            units={units}
            active={destination?.name === place.name}
            onSelect={() => {
              chooseDestination(place);
              setQuery("");
              setHits([]);
            }}
          />
        ))}
        {!searching && query.trim().length >= 2 && hits.length === 0 ? (
          <p className="px-1 py-2 text-sm text-muted">No matches. Try a park or neighborhood name.</p>
        ) : null}
      </div>

      {destination && query.trim().length < 2 ? (
        <div className="mt-3 flex items-center gap-3 rounded-lg border border-line bg-surface px-3 py-3">
          <MapPin className="size-4 shrink-0 text-early" />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-fg">{destination.name}</p>
            <p className="truncate text-xs text-muted">
              {destination.area}
              {origin && planMeters != null ? ` · ${formatDistance(planMeters, units)}` : ""}
            </p>
          </div>
        </div>
      ) : null}

      {chips.length > 0 ? (
        <div className="mt-4">
          <p className="text-xs font-medium uppercase tracking-label text-muted">
            {recent.length ? "Recent" : "Nearby"}
          </p>
          <div className="mt-2 flex flex-col gap-1">
            {chips.map((place) => (
              <PlaceRow
                key={`${place.name}-${place.lat}`}
                place={place}
                origin={origin}
                units={units}
                active={destination?.name === place.name}
                onSelect={() => chooseDestination(place)}
              />
            ))}
          </div>
        </div>
      ) : null}

      <section className="mt-8">
        <p className="text-xs font-medium uppercase tracking-label text-muted">Arrive by</p>
        {destination ? (
          <>
            <div className="mt-2 flex items-center gap-2">
              <Input
                type="time"
                value={arriveByInput}
                onChange={(e) => setArriveByInput(e.target.value)}
                aria-label="Arrive by time"
                className="flex-1 tabular-nums"
              />
              <Button
                variant="outline"
                size="md"
                onClick={() => bumpArriveBy(-5)}
                aria-label="Five minutes earlier"
              >
                −5
              </Button>
              <Button
                variant="outline"
                size="md"
                onClick={() => bumpArriveBy(5)}
                aria-label="Five minutes later"
              >
                +5
              </Button>
            </div>
            <p className="mt-2 text-sm text-muted">
              {arriveBy
                ? `${formatClock(arriveBy)}${walkMs != null ? ` · ${formatDuration(walkMs)} on foot` : ""}`
                : "Set a time"}
            </p>
          </>
        ) : (
          <p className="mt-2 text-sm text-muted">Pick a destination first</p>
        )}
      </section>

      <div className="sticky bottom-0 mt-auto -mx-5 border-t border-line bg-bg px-5 pt-4 pb-[max(env(safe-area-inset-bottom),1.25rem)]">
        <GpsLine status={geoStatus} error={geoError} onEnable={requestGps} />
        <Button onClick={onStart} disabled={!canStart} className="mt-3 w-full">
          <Navigation className="size-4" />
          Start walking
        </Button>
        <Button variant="outline" onClick={onDemo} className="mt-2 w-full">
          Preview a walk
        </Button>
      </div>
    </main>
  );
}

function PlaceRow({
  place,
  origin,
  units,
  active,
  onSelect,
}: {
  place: Place;
  origin: LatLon | null;
  units: Units;
  active: boolean;
  onSelect: () => void;
}) {
  const dist = origin ? formatDistance(haversineM(origin, place), units) : null;
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        "flex min-h-12 items-center gap-3 rounded-md px-3 py-2.5 text-left transition-colors duration-150",
        active ? "bg-surface-2" : "hover:bg-surface",
      )}
    >
      <MapPin className="size-4 shrink-0 text-muted" />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-medium text-fg">{place.name}</span>
        <span className="block truncate text-xs text-muted">{place.area}</span>
      </span>
      {dist ? <span className="text-xs tabular-nums text-muted">{dist}</span> : null}
    </button>
  );
}

function GpsLine({
  status,
  error,
  onEnable,
}: {
  status: GeoStatus;
  error: string | null;
  onEnable: () => void;
}) {
  if (status === "live") {
    return <p className="text-center text-xs text-early">GPS ready</p>;
  }
  if (status === "requesting") {
    return <p className="text-center text-xs text-muted">Waiting for GPS…</p>;
  }
  if (status === "denied" || status === "unavailable") {
    return (
      <button type="button" onClick={onEnable} className="w-full text-center text-xs text-muted">
        {error ? `${error} Tap to retry, or preview a walk.` : "Location is off. Tap to retry, or preview a walk."}
      </button>
    );
  }
  return (
    <button type="button" onClick={onEnable} className="w-full text-center text-xs text-muted">
      Enable location to start a live walk
    </button>
  );
}
