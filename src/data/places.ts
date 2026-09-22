import { haversineM, type LatLon } from "@/lib/geo";

export type Place = LatLon & {
  name: string;
  area: string;
};

export const PLACES: Place[] = [
  { name: "Gantry Plaza State Park", area: "Long Island City", lat: 40.74551, lon: -73.95875 },
  { name: "Hunters Point South Park", area: "Long Island City", lat: 40.7419, lon: -73.9618 },
  { name: "Pepsi-Cola Sign", area: "Long Island City", lat: 40.7472, lon: -73.9575 },
  { name: "MoMA PS1", area: "Long Island City", lat: 40.7456, lon: -73.947 },
  { name: "LIC Ferry Landing", area: "Long Island City", lat: 40.7413, lon: -73.9614 },
  { name: "Queensbridge Park", area: "Long Island City", lat: 40.7565, lon: -73.9455 },
  { name: "Socrates Sculpture Park", area: "Astoria", lat: 40.7685, lon: -73.9367 },
  { name: "Astoria Park", area: "Astoria", lat: 40.77843, lon: -73.92291 },
  { name: "Rainey Park", area: "Astoria", lat: 40.7665, lon: -73.9405 },
  { name: "Sunnyside Gardens Park", area: "Sunnyside", lat: 40.7445, lon: -73.9175 },
  { name: "Times Square", area: "Manhattan", lat: 40.758, lon: -73.9855 },
  { name: "Bryant Park", area: "Manhattan", lat: 40.7536, lon: -73.9832 },
  { name: "Grand Central Terminal", area: "Manhattan", lat: 40.7527, lon: -73.9772 },
  { name: "Rockefeller Center", area: "Manhattan", lat: 40.7587, lon: -73.9787 },
  { name: "Central Park — The Pond", area: "Manhattan", lat: 40.7675, lon: -73.9762 },
  { name: "Central Park — Bethesda Fountain", area: "Manhattan", lat: 40.7743, lon: -73.9708 },
  { name: "Washington Square Park", area: "Manhattan", lat: 40.7308, lon: -73.9973 },
  { name: "Union Square", area: "Manhattan", lat: 40.7359, lon: -73.9911 },
  { name: "Madison Square Park", area: "Manhattan", lat: 40.742, lon: -73.988 },
  { name: "The High Line", area: "Manhattan", lat: 40.748, lon: -74.0048 },
  { name: "Hudson Yards", area: "Manhattan", lat: 40.7536, lon: -74.0018 },
  { name: "Penn Station", area: "Manhattan", lat: 40.7506, lon: -73.9935 },
  { name: "Brooklyn Bridge", area: "New York", lat: 40.7061, lon: -73.9969 },
  { name: "Brooklyn Bridge Park", area: "Brooklyn", lat: 40.70029, lon: -73.9967 },
  { name: "Domino Park", area: "Williamsburg", lat: 40.7148, lon: -73.9676 },
  { name: "McCarren Park", area: "Williamsburg", lat: 40.721, lon: -73.9522 },
  { name: "Prospect Park", area: "Brooklyn", lat: 40.6602, lon: -73.969 },
  { name: "The Vessel", area: "Hudson Yards", lat: 40.7538, lon: -74.0022 },
  { name: "United Nations Headquarters", area: "Manhattan", lat: 40.749, lon: -73.968 },
  { name: "Golden Gate Bridge", area: "San Francisco", lat: 37.8199, lon: -122.4783 },
  { name: "Griffith Observatory", area: "Los Angeles", lat: 34.1184, lon: -118.3004 },
  { name: "Millennium Park", area: "Chicago", lat: 41.8826, lon: -87.6226 },
  { name: "Hyde Park", area: "London", lat: 51.5073, lon: -0.1657 },
  { name: "Trafalgar Square", area: "London", lat: 51.508, lon: -0.1281 },
  { name: "Eiffel Tower", area: "Paris", lat: 48.8584, lon: 2.2945 },
  { name: "Colosseum", area: "Rome", lat: 41.8902, lon: 12.4922 },
  { name: "Acropolis", area: "Athens", lat: 37.9715, lon: 23.7267 },
  { name: "Syntagma Square", area: "Athens", lat: 37.9755, lon: 23.7348 },
  { name: "National Garden", area: "Athens", lat: 37.973, lon: 23.7378 },
];

function normalize(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

export function searchGazetteer(query: string, origin?: LatLon | null): Place[] {
  const q = normalize(query);
  if (q.length < 2) return [];
  const tokens = q.split(" ").filter(Boolean);
  const scored = PLACES.map((place) => {
    const hay = normalize(`${place.name} ${place.area}`);
    let score = 0;
    if (hay.includes(q)) score += 8;
    for (const t of tokens) {
      if (hay.includes(t)) score += 3;
    }
    if (normalize(place.name).startsWith(q)) score += 4;
    return { place, score };
  }).filter((x) => x.score > 0);
  scored.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    if (!origin) return a.place.name.localeCompare(b.place.name);
    const da = (a.place.lat - origin.lat) ** 2 + (a.place.lon - origin.lon) ** 2;
    const db = (b.place.lat - origin.lat) ** 2 + (b.place.lon - origin.lon) ** 2;
    return da - db;
  });
  return scored.slice(0, 8).map((x) => x.place);
}

export function nearbyPlaces(origin: LatLon, limit = 3, radiusM = 3500): Place[] {
  return PLACES.map((p) => ({ p, d: haversineM(origin, p) }))
    .filter((x) => x.d <= radiusM && x.d > 80)
    .sort((a, b) => a.d - b.d)
    .slice(0, limit)
    .map((x) => x.p);
}
