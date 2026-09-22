import { nearbyPlaces, searchGazetteer, type Place } from "@/data/places";
import { haversineM, type LatLon } from "@/lib/geo";

const COORD_RE = /^\s*(-?\d{1,3}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)\s*$/;

function parseCoords(query: string): Place | null {
  const m = COORD_RE.exec(query);
  if (!m) return null;
  const lat = Number(m[1]);
  const lon = Number(m[2]);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
  return {
    name: `${lat.toFixed(5)}, ${lon.toFixed(5)}`,
    area: "Coordinates",
    lat,
    lon,
  };
}

type OpenMeteoHit = {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  country?: string;
  admin1?: string;
  admin2?: string;
};

function placeKey(p: Place) {
  return `${p.name.toLowerCase()}|${p.lat.toFixed(3)}|${p.lon.toFixed(3)}`;
}

function normalize(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function nameScore(query: string, place: Place): number {
  const q = normalize(query);
  const name = normalize(place.name);
  const area = normalize(place.area);
  if (!q || !name) return 0;
  if (name === q) return 120;
  if (name.startsWith(`${q} `) || name.endsWith(` ${q}`) || name.includes(` ${q} `)) return 90;
  if (area === q || area.startsWith(`${q} `)) return 40;
  const tokens = q.split(" ").filter(Boolean);
  let hits = 0;
  for (const token of tokens) {
    if (name.split(" ").includes(token) || area.split(" ").includes(token)) hits += 1;
  }
  return hits === tokens.length && hits > 0 ? 55 : 0;
}

function rankPlaces(
  query: string,
  places: Place[],
  origin?: LatLon | null,
  preferred?: Set<string>,
): Place[] {
  const scored = places
    .map((place) => {
      let score = nameScore(query, place);
      if (score <= 0) return { place, score: 0 };
      if (preferred?.has(placeKey(place))) score += 18;
      if (origin) {
        const d = haversineM(origin, place);
        if (d < 3_000) score += 36;
        else if (d < 20_000) score += 22;
        else if (d < 80_000) score += 8;
        else score -= 24;
      }
      return { place, score };
    })
    .filter((row) => row.score > 0);

  const best = scored.reduce((max, row) => Math.max(max, row.score), 0);
  const floor = best >= 80 ? 40 : 0;
  scored.sort((a, b) => b.score - a.score || a.place.name.localeCompare(b.place.name));
  const seen = new Set<string>();
  const out: Place[] = [];
  for (const row of scored) {
    if (row.score < floor) continue;
    const key = placeKey(row.place);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(row.place);
    if (out.length >= 6) break;
  }
  return out;
}

async function searchOpenMeteo(query: string): Promise<Place[]> {
  const url = new URL("https://geocoding-api.open-meteo.com/v1/search");
  url.searchParams.set("name", query);
  url.searchParams.set("count", "12");
  url.searchParams.set("language", "en");
  url.searchParams.set("format", "json");
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 2500);
  try {
    const res = await fetch(url.toString(), { signal: ctrl.signal });
    if (!res.ok) return [];
    const data = (await res.json()) as { results?: OpenMeteoHit[] };
    return (data.results ?? []).map((hit) => ({
      name: hit.name,
      area: [hit.admin2, hit.admin1, hit.country].filter(Boolean).join(", "),
      lat: hit.latitude,
      lon: hit.longitude,
    }));
  } catch {
    return [];
  } finally {
    clearTimeout(timer);
  }
}

export async function searchDestinations(
  query: string,
  origin?: LatLon | null,
): Promise<Place[]> {
  const q = query.trim();
  if (q.length < 2) return [];

  const coord = parseCoords(q);
  if (coord) return [coord];

  const local = searchGazetteer(q, origin);
  let remote: Place[] = [];
  try {
    remote = await searchOpenMeteo(q);
  } catch {
    remote = [];
  }

  const merged = new Map<string, Place>();
  for (const p of [...local, ...remote]) {
    const key = placeKey(p);
    if (!merged.has(key)) merged.set(key, p);
  }
  return rankPlaces(q, [...merged.values()], origin, new Set(local.map(placeKey)));
}

export function suggestionsFor(origin?: LatLon | null): Place[] {
  if (origin) {
    const near = nearbyPlaces(origin, 3);
    if (near.length) return near;
  }
  return [
    { name: "Gantry Plaza State Park", area: "Long Island City", lat: 40.74551, lon: -73.95875 },
    { name: "Times Square", area: "Manhattan", lat: 40.758, lon: -73.9855 },
    { name: "Central Park — The Pond", area: "Manhattan", lat: 40.7675, lon: -73.9762 },
  ];
}
