import type { LatLon } from "@/lib/geo";

type OsrmRoute = {
  routes?: { distance?: number }[];
};

/** Walking distance in meters along streets. Null if the router is unavailable. */
export async function walkDistanceM(from: LatLon, to: LatLon): Promise<number | null> {
  const url =
    `https://router.project-osrm.org/route/v1/foot/` +
    `${from.lon},${from.lat};${to.lon},${to.lat}?overview=false`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 4000);
  try {
    const res = await fetch(url, { signal: ctrl.signal });
    if (!res.ok) return null;
    const data = (await res.json()) as OsrmRoute;
    const meters = data.routes?.[0]?.distance;
    return typeof meters === "number" && meters > 0 ? meters : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}
