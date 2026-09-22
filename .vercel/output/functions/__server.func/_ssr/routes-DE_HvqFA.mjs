import { i as __toESM } from "../_runtime.mjs";
import { L as require_react, v as require_jsx_runtime } from "../_libs/@tanstack/react-router+[...].mjs";
import { i as MapPin, n as Search, r as Navigation } from "../_libs/lucide-react.mjs";
import { n as clsx, t as cva } from "../_libs/class-variance-authority+clsx.mjs";
import { t as twMerge } from "../_libs/tailwind-merge.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/routes-DE_HvqFA.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var EARTH_M = 6371e3;
function toRad(deg) {
	return deg * Math.PI / 180;
}
function toDeg(rad) {
	return rad * 180 / Math.PI;
}
function haversineM(a, b) {
	const φ1 = toRad(a.lat);
	const φ2 = toRad(b.lat);
	const Δφ = toRad(b.lat - a.lat);
	const Δλ = toRad(b.lon - a.lon);
	const s = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
	return 2 * EARTH_M * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
}
function bearingDeg(from, to) {
	const φ1 = toRad(from.lat);
	const φ2 = toRad(to.lat);
	const Δλ = toRad(to.lon - from.lon);
	const y = Math.sin(Δλ) * Math.cos(φ2);
	const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
	return (toDeg(Math.atan2(y, x)) + 360) % 360;
}
function destinationPoint(from, bearing, distM) {
	const δ = distM / EARTH_M;
	const θ = toRad(bearing);
	const φ1 = toRad(from.lat);
	const λ1 = toRad(from.lon);
	const φ2 = Math.asin(Math.sin(φ1) * Math.cos(δ) + Math.cos(φ1) * Math.sin(δ) * Math.cos(θ));
	const λ2 = λ1 + Math.atan2(Math.sin(θ) * Math.sin(δ) * Math.cos(φ1), Math.cos(δ) - Math.sin(φ1) * Math.sin(φ2));
	return {
		lat: toDeg(φ2),
		lon: (toDeg(λ2) + 540) % 360 - 180
	};
}
function moveTowards(from, to, distM) {
	const d = haversineM(from, to);
	if (d <= distM || d === 0) return { ...to };
	return destinationPoint(from, bearingDeg(from, to), distM);
}
function cardinal(deg) {
	return [
		"N",
		"NE",
		"E",
		"SE",
		"S",
		"SW",
		"W",
		"NW"
	][Math.round(deg / 45) % 8] ?? "N";
}
/** Seconds ahead of schedule (positive = early, negative = late). */
function scheduleDeltaSec(args) {
	const budgetMs = args.arriveBy - args.startAt;
	if (budgetMs <= 0 || args.startDistanceM <= 0) return 0;
	const requiredMps = args.startDistanceM / (budgetMs / 1e3);
	if (requiredMps <= 0) return 0;
	const expectedCovered = requiredMps * Math.max(0, (args.now - args.startAt) / 1e3);
	return (Math.max(0, args.startDistanceM - args.remainingM) - expectedCovered) / requiredMps;
}
function walkEstimateMs(distanceM, paceMps = 1.34) {
	if (distanceM <= 0) return 0;
	return distanceM / paceMps * 1e3;
}
function roundUpToMinute(ms) {
	return Math.ceil(ms / 6e4) * 6e4;
}
var PLACES = [
	{
		name: "Gantry Plaza State Park",
		area: "Long Island City",
		lat: 40.74551,
		lon: -73.95875
	},
	{
		name: "Hunters Point South Park",
		area: "Long Island City",
		lat: 40.7419,
		lon: -73.9618
	},
	{
		name: "Pepsi-Cola Sign",
		area: "Long Island City",
		lat: 40.7472,
		lon: -73.9575
	},
	{
		name: "MoMA PS1",
		area: "Long Island City",
		lat: 40.7456,
		lon: -73.947
	},
	{
		name: "LIC Ferry Landing",
		area: "Long Island City",
		lat: 40.7413,
		lon: -73.9614
	},
	{
		name: "Queensbridge Park",
		area: "Long Island City",
		lat: 40.7565,
		lon: -73.9455
	},
	{
		name: "Socrates Sculpture Park",
		area: "Astoria",
		lat: 40.7685,
		lon: -73.9367
	},
	{
		name: "Astoria Park",
		area: "Astoria",
		lat: 40.77843,
		lon: -73.92291
	},
	{
		name: "Rainey Park",
		area: "Astoria",
		lat: 40.7665,
		lon: -73.9405
	},
	{
		name: "Sunnyside Gardens Park",
		area: "Sunnyside",
		lat: 40.7445,
		lon: -73.9175
	},
	{
		name: "Times Square",
		area: "Manhattan",
		lat: 40.758,
		lon: -73.9855
	},
	{
		name: "Bryant Park",
		area: "Manhattan",
		lat: 40.7536,
		lon: -73.9832
	},
	{
		name: "Grand Central Terminal",
		area: "Manhattan",
		lat: 40.7527,
		lon: -73.9772
	},
	{
		name: "Rockefeller Center",
		area: "Manhattan",
		lat: 40.7587,
		lon: -73.9787
	},
	{
		name: "Central Park — The Pond",
		area: "Manhattan",
		lat: 40.7675,
		lon: -73.9762
	},
	{
		name: "Central Park — Bethesda Fountain",
		area: "Manhattan",
		lat: 40.7743,
		lon: -73.9708
	},
	{
		name: "Washington Square Park",
		area: "Manhattan",
		lat: 40.7308,
		lon: -73.9973
	},
	{
		name: "Union Square",
		area: "Manhattan",
		lat: 40.7359,
		lon: -73.9911
	},
	{
		name: "Madison Square Park",
		area: "Manhattan",
		lat: 40.742,
		lon: -73.988
	},
	{
		name: "The High Line",
		area: "Manhattan",
		lat: 40.748,
		lon: -74.0048
	},
	{
		name: "Hudson Yards",
		area: "Manhattan",
		lat: 40.7536,
		lon: -74.0018
	},
	{
		name: "Penn Station",
		area: "Manhattan",
		lat: 40.7506,
		lon: -73.9935
	},
	{
		name: "Brooklyn Bridge",
		area: "New York",
		lat: 40.7061,
		lon: -73.9969
	},
	{
		name: "Brooklyn Bridge Park",
		area: "Brooklyn",
		lat: 40.70029,
		lon: -73.9967
	},
	{
		name: "Domino Park",
		area: "Williamsburg",
		lat: 40.7148,
		lon: -73.9676
	},
	{
		name: "McCarren Park",
		area: "Williamsburg",
		lat: 40.721,
		lon: -73.9522
	},
	{
		name: "Prospect Park",
		area: "Brooklyn",
		lat: 40.6602,
		lon: -73.969
	},
	{
		name: "The Vessel",
		area: "Hudson Yards",
		lat: 40.7538,
		lon: -74.0022
	},
	{
		name: "United Nations Headquarters",
		area: "Manhattan",
		lat: 40.749,
		lon: -73.968
	},
	{
		name: "Golden Gate Bridge",
		area: "San Francisco",
		lat: 37.8199,
		lon: -122.4783
	},
	{
		name: "Griffith Observatory",
		area: "Los Angeles",
		lat: 34.1184,
		lon: -118.3004
	},
	{
		name: "Millennium Park",
		area: "Chicago",
		lat: 41.8826,
		lon: -87.6226
	},
	{
		name: "Hyde Park",
		area: "London",
		lat: 51.5073,
		lon: -.1657
	},
	{
		name: "Trafalgar Square",
		area: "London",
		lat: 51.508,
		lon: -.1281
	},
	{
		name: "Eiffel Tower",
		area: "Paris",
		lat: 48.8584,
		lon: 2.2945
	},
	{
		name: "Colosseum",
		area: "Rome",
		lat: 41.8902,
		lon: 12.4922
	},
	{
		name: "Acropolis",
		area: "Athens",
		lat: 37.9715,
		lon: 23.7267
	},
	{
		name: "Syntagma Square",
		area: "Athens",
		lat: 37.9755,
		lon: 23.7348
	},
	{
		name: "National Garden",
		area: "Athens",
		lat: 37.973,
		lon: 23.7378
	}
];
function normalize$1(s) {
	return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}
function searchGazetteer(query, origin) {
	const q = normalize$1(query);
	if (q.length < 2) return [];
	const tokens = q.split(" ").filter(Boolean);
	const scored = PLACES.map((place) => {
		const hay = normalize$1(`${place.name} ${place.area}`);
		let score = 0;
		if (hay.includes(q)) score += 8;
		for (const t of tokens) if (hay.includes(t)) score += 3;
		if (normalize$1(place.name).startsWith(q)) score += 4;
		return {
			place,
			score
		};
	}).filter((x) => x.score > 0);
	scored.sort((a, b) => {
		if (b.score !== a.score) return b.score - a.score;
		if (!origin) return a.place.name.localeCompare(b.place.name);
		return (a.place.lat - origin.lat) ** 2 + (a.place.lon - origin.lon) ** 2 - ((b.place.lat - origin.lat) ** 2 + (b.place.lon - origin.lon) ** 2);
	});
	return scored.slice(0, 8).map((x) => x.place);
}
function nearbyPlaces(origin, limit = 3, radiusM = 3500) {
	return PLACES.map((p) => ({
		p,
		d: haversineM(origin, p)
	})).filter((x) => x.d <= radiusM && x.d > 80).sort((a, b) => a.d - b.d).slice(0, limit).map((x) => x.p);
}
var COORD_RE = /^\s*(-?\d{1,3}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)\s*$/;
function parseCoords(query) {
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
		lon
	};
}
function placeKey(p) {
	return `${p.name.toLowerCase()}|${p.lat.toFixed(3)}|${p.lon.toFixed(3)}`;
}
function normalize(s) {
	return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}
function nameScore(query, place) {
	const q = normalize(query);
	const name = normalize(place.name);
	const area = normalize(place.area);
	if (!q || !name) return 0;
	if (name === q) return 120;
	if (name.startsWith(`${q} `) || name.endsWith(` ${q}`) || name.includes(` ${q} `)) return 90;
	if (area === q || area.startsWith(`${q} `)) return 40;
	const tokens = q.split(" ").filter(Boolean);
	let hits = 0;
	for (const token of tokens) if (name.split(" ").includes(token) || area.split(" ").includes(token)) hits += 1;
	return hits === tokens.length && hits > 0 ? 55 : 0;
}
function rankPlaces(query, places, origin, preferred) {
	const scored = places.map((place) => {
		let score = nameScore(query, place);
		if (score <= 0) return {
			place,
			score: 0
		};
		if (preferred?.has(placeKey(place))) score += 18;
		if (origin) {
			const d = haversineM(origin, place);
			if (d < 3e3) score += 36;
			else if (d < 2e4) score += 22;
			else if (d < 8e4) score += 8;
			else score -= 24;
		}
		return {
			place,
			score
		};
	}).filter((row) => row.score > 0);
	const floor = scored.reduce((max, row) => Math.max(max, row.score), 0) >= 80 ? 40 : 0;
	scored.sort((a, b) => b.score - a.score || a.place.name.localeCompare(b.place.name));
	const seen = /* @__PURE__ */ new Set();
	const out = [];
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
async function searchOpenMeteo(query) {
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
		return ((await res.json()).results ?? []).map((hit) => ({
			name: hit.name,
			area: [
				hit.admin2,
				hit.admin1,
				hit.country
			].filter(Boolean).join(", "),
			lat: hit.latitude,
			lon: hit.longitude
		}));
	} catch {
		return [];
	} finally {
		clearTimeout(timer);
	}
}
async function searchDestinations(query, origin) {
	const q = query.trim();
	if (q.length < 2) return [];
	const coord = parseCoords(q);
	if (coord) return [coord];
	const local = searchGazetteer(q, origin);
	let remote = [];
	try {
		remote = await searchOpenMeteo(q);
	} catch {
		remote = [];
	}
	const merged = /* @__PURE__ */ new Map();
	for (const p of [...local, ...remote]) {
		const key = placeKey(p);
		if (!merged.has(key)) merged.set(key, p);
	}
	return rankPlaces(q, [...merged.values()], origin, new Set(local.map(placeKey)));
}
function suggestionsFor(origin) {
	if (origin) {
		const near = nearbyPlaces(origin, 3);
		if (near.length) return near;
	}
	return [
		{
			name: "Gantry Plaza State Park",
			area: "Long Island City",
			lat: 40.74551,
			lon: -73.95875
		},
		{
			name: "Times Square",
			area: "Manhattan",
			lat: 40.758,
			lon: -73.9855
		},
		{
			name: "Central Park — The Pond",
			area: "Manhattan",
			lat: 40.7675,
			lon: -73.9762
		}
	];
}
function detectUnits() {
	if (typeof navigator === "undefined") return "imperial";
	return (navigator.language || "en-US").startsWith("en-US") ? "imperial" : "metric";
}
function formatSpeed(mps, units) {
	if (!Number.isFinite(mps) || mps < .15) return {
		value: "0.0",
		unit: units === "imperial" ? "mph" : "km/h"
	};
	if (units === "imperial") return {
		value: (mps * 2.236936).toFixed(1),
		unit: "mph"
	};
	return {
		value: (mps * 3.6).toFixed(1),
		unit: "km/h"
	};
}
function formatDistance(meters, units) {
	if (!Number.isFinite(meters) || meters < 0) return "—";
	if (units === "imperial") {
		const feet = meters * 3.28084;
		if (feet < 900) return `${Math.round(feet)} ft`;
		const miles = meters / 1609.344;
		return `${miles >= 10 ? miles.toFixed(0) : miles.toFixed(1)} mi`;
	}
	if (meters < 280) return `${Math.round(meters)} m`;
	const km = meters / 1e3;
	return `${km >= 10 ? km.toFixed(0) : km.toFixed(1)} km`;
}
function formatClock(ms) {
	return new Date(ms).toLocaleTimeString(void 0, {
		hour: "numeric",
		minute: "2-digit"
	});
}
function formatDuration(ms) {
	const totalMin = Math.max(0, Math.round(ms / 6e4));
	if (totalMin < 60) return `${totalMin} min`;
	const h = Math.floor(totalMin / 60);
	const m = totalMin % 60;
	return m ? `${h} hr ${m} min` : `${h} hr`;
}
function formatDelta(sec) {
	const abs = Math.abs(sec);
	if (!Number.isFinite(sec) || abs < 3) return {
		sign: "",
		clock: "0:00",
		label: "on time",
		tone: "ontime"
	};
	const sign = sec > 0 ? "+" : "−";
	const s = Math.round(abs);
	const h = Math.floor(s / 3600);
	const m = Math.floor(s % 3600 / 60);
	const r = s % 60;
	return {
		sign,
		clock: h > 0 ? `${h}:${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}` : `${m}:${String(r).padStart(2, "0")}`,
		label: sec > 0 ? "early" : "late",
		tone: sec > 0 ? "early" : "late"
	};
}
function formatHeading(deg) {
	const n = (Math.round(deg) % 360 + 360) % 360;
	return `${String(n).padStart(3, "0")}°`;
}
function timeInputValue(ms) {
	const d = new Date(ms);
	return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
function parseTimeInput(value, now = Date.now()) {
	const m = /^(\d{1,2}):(\d{2})$/.exec(value);
	if (!m) return null;
	const hours = Number(m[1]);
	const minutes = Number(m[2]);
	if (hours > 23 || minutes > 59) return null;
	const d = new Date(now);
	d.setHours(hours, minutes, 0, 0);
	if (d.getTime() < now - 3e4) d.setDate(d.getDate() + 1);
	return d.getTime();
}
function cn(...inputs) {
	return twMerge(clsx(inputs));
}
var buttonVariants = cva("inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium transition-[opacity,transform,background-color,color] duration-150 ease-out active:not-disabled:scale-[0.96] disabled:pointer-events-none disabled:opacity-40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/70 focus-visible:ring-offset-2 focus-visible:ring-offset-bg", {
	variants: {
		variant: {
			primary: "bg-accent text-accent-fg hover:opacity-90",
			ghost: "bg-transparent text-fg hover:bg-surface-2",
			outline: "border border-line bg-transparent text-fg hover:bg-surface"
		},
		size: {
			lg: "h-14 rounded-lg px-5 text-base",
			md: "h-11 rounded-md px-4 text-sm",
			sm: "h-9 rounded-sm px-3 text-sm",
			icon: "size-11 rounded-md"
		}
	},
	defaultVariants: {
		variant: "primary",
		size: "lg"
	}
});
var Button = (0, import_react.forwardRef)(function Button({ className, variant, size, type = "button", ...props }, ref) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
		ref,
		type,
		className: cn(buttonVariants({
			variant,
			size
		}), className),
		...props
	});
});
var Input = (0, import_react.forwardRef)(function Input({ className, type = "text", ...props }, ref) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
		ref,
		type,
		className: cn("flex h-14 w-full rounded-lg border border-line bg-surface px-4 text-base text-fg", "placeholder:text-faint", "transition-[border-color] duration-150 ease-out", "focus-visible:border-accent/60 focus-visible:outline-none", "disabled:opacity-50", className),
		...props
	});
});
function SetupView(props) {
	const { units, setUnits, destination, origin, geoStatus, geoError, requestGps, arriveBy, arriveByInput, setArriveByInput, bumpArriveBy, chooseDestination, recent, planMeters, canStart, onStart, onDemo } = props;
	const searchId = (0, import_react.useId)();
	const [query, setQuery] = (0, import_react.useState)("");
	const [hits, setHits] = (0, import_react.useState)([]);
	const [searching, setSearching] = (0, import_react.useState)(false);
	const requestRef = (0, import_react.useRef)(0);
	(0, import_react.useEffect)(() => {
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
			searchDestinations(q, origin).then((results) => {
				if (requestRef.current !== id) return;
				setHits(results.length ? results : local);
				setSearching(false);
			}).catch(() => {
				if (requestRef.current !== id) return;
				setHits(local);
				setSearching(false);
			});
		}, 220);
		return () => window.clearTimeout(timer);
	}, [origin, query]);
	const chips = query.trim().length < 2 && !destination ? recent.length ? recent.slice(0, 3) : suggestionsFor(origin) : [];
	const walkMs = destination && origin && planMeters != null ? walkEstimateMs(planMeters) : null;
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
		className: "mx-auto flex min-h-dvh w-full max-w-md flex-col px-5 pt-[max(env(safe-area-inset-top),1.5rem)]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
				className: "flex items-start justify-between gap-3",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-xs font-medium uppercase tracking-label text-muted",
					children: "Keep the Pace"
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "mt-2 font-sans text-3xl font-medium leading-tight tracking-tight text-fg",
					children: "Arrive on time."
				})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
					type: "button",
					onClick: () => setUnits(units === "imperial" ? "metric" : "imperial"),
					className: "mt-1 rounded-sm px-2 py-1 text-xs font-medium tracking-wide text-muted transition-colors duration-150 hover:text-fg",
					"aria-label": "Toggle units",
					children: units === "imperial" ? "mph" : "km/h"
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("label", {
				htmlFor: searchId,
				className: "mt-8 text-xs font-medium uppercase tracking-label text-muted",
				children: "Destination"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "relative mt-2",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "pointer-events-none absolute top-1/2 left-4 size-4 -translate-y-1/2 text-faint" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
					id: searchId,
					value: query,
					onChange: (e) => {
						setQuery(e.target.value);
					},
					placeholder: "Park, plaza, street…",
					autoComplete: "off",
					autoCorrect: "off",
					spellCheck: false,
					className: "pl-11"
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-3 flex flex-col gap-1",
				children: [
					searching ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "px-1 py-2 text-sm text-muted",
						children: "Searching…"
					}) : null,
					hits.map((place) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlaceRow, {
						place,
						origin,
						units,
						active: destination?.name === place.name,
						onSelect: () => {
							chooseDestination(place);
							setQuery("");
							setHits([]);
						}
					}, `${place.name}-${place.lat}`)),
					!searching && query.trim().length >= 2 && hits.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "px-1 py-2 text-sm text-muted",
						children: "No matches. Try a park or neighborhood name."
					}) : null
				]
			}),
			destination && query.trim().length < 2 ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-3 flex items-center gap-3 rounded-lg border border-line bg-surface px-3 py-3",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(MapPin, { className: "size-4 shrink-0 text-early" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "min-w-0 flex-1",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "truncate text-sm font-medium text-fg",
						children: destination.name
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "truncate text-xs text-muted",
						children: [destination.area, origin && planMeters != null ? ` · ${formatDistance(planMeters, units)}` : ""]
					})]
				})]
			}) : null,
			chips.length > 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-4",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-xs font-medium uppercase tracking-label text-muted",
					children: recent.length ? "Recent" : "Nearby"
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mt-2 flex flex-col gap-1",
					children: chips.map((place) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlaceRow, {
						place,
						origin,
						units,
						active: destination?.name === place.name,
						onSelect: () => chooseDestination(place)
					}, `${place.name}-${place.lat}`))
				})]
			}) : null,
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				className: "mt-8",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-xs font-medium uppercase tracking-label text-muted",
					children: "Arrive by"
				}), destination ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-2 flex items-center gap-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							type: "time",
							value: arriveByInput,
							onChange: (e) => setArriveByInput(e.target.value),
							"aria-label": "Arrive by time",
							className: "flex-1 tabular-nums"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							variant: "outline",
							size: "md",
							onClick: () => bumpArriveBy(-5),
							"aria-label": "Five minutes earlier",
							children: "−5"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							variant: "outline",
							size: "md",
							onClick: () => bumpArriveBy(5),
							"aria-label": "Five minutes later",
							children: "+5"
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-2 text-sm text-muted",
					children: arriveBy ? `${formatClock(arriveBy)}${walkMs != null ? ` · ${formatDuration(walkMs)} on foot` : ""}` : "Set a time"
				})] }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-2 text-sm text-muted",
					children: "Pick a destination first"
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "sticky bottom-0 mt-auto -mx-5 border-t border-line bg-bg px-5 pt-4 pb-[max(env(safe-area-inset-bottom),1.25rem)]",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(GpsLine, {
						status: geoStatus,
						error: geoError,
						onEnable: requestGps
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Button, {
						onClick: onStart,
						disabled: !canStart,
						className: "mt-3 w-full",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Navigation, { className: "size-4" }), "Start walking"]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
						variant: "outline",
						onClick: onDemo,
						className: "mt-2 w-full",
						children: "Preview a walk"
					})
				]
			})
		]
	});
}
function PlaceRow({ place, origin, units, active, onSelect }) {
	const dist = origin ? formatDistance(haversineM(origin, place), units) : null;
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
		type: "button",
		onClick: onSelect,
		className: cn("flex min-h-12 items-center gap-3 rounded-md px-3 py-2.5 text-left transition-colors duration-150", active ? "bg-surface-2" : "hover:bg-surface"),
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(MapPin, { className: "size-4 shrink-0 text-muted" }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
				className: "min-w-0 flex-1",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "block truncate text-sm font-medium text-fg",
					children: place.name
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "block truncate text-xs text-muted",
					children: place.area
				})]
			}),
			dist ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "text-xs tabular-nums text-muted",
				children: dist
			}) : null
		]
	});
}
function GpsLine({ status, error, onEnable }) {
	if (status === "live") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: "text-center text-xs text-early",
		children: "GPS ready"
	});
	if (status === "requesting") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: "text-center text-xs text-muted",
		children: "Waiting for GPS…"
	});
	if (status === "denied" || status === "unavailable") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
		type: "button",
		onClick: onEnable,
		className: "w-full text-center text-xs text-muted",
		children: error ? `${error} Tap to retry, or preview a walk.` : "Location is off. Tap to retry, or preview a walk."
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
		type: "button",
		onClick: onEnable,
		className: "w-full text-center text-xs text-muted",
		children: "Enable location to start a live walk"
	});
}
function WalkView({ session, metrics, units, phase, onEnd }) {
	const speed = formatSpeed(metrics.speedMps, units);
	const delta = formatDelta(metrics.deltaSec);
	const remaining = formatDistance(metrics.remaining, units);
	const arrived = phase === "arrived" || metrics.arrived;
	const deltaColor = arrived || delta.tone === "ontime" ? "text-ontime" : delta.tone === "early" ? "text-early" : "text-late";
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
		className: "relative mx-auto flex min-h-dvh w-full max-w-lg flex-col px-6 pt-[max(env(safe-area-inset-top),1.25rem)] pb-[max(env(safe-area-inset-bottom),1.25rem)] select-none",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
				className: "flex items-start justify-between gap-4",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "min-w-0",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-xs font-medium uppercase tracking-label text-muted",
							children: "Keep the Pace"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
							className: "mt-1 truncate text-xl font-medium tracking-tight text-fg",
							children: session.dest.name
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-0.5 text-sm text-muted",
							children: arrived ? "Arrived" : `${remaining} left · ${formatClock(session.arriveBy)}`
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
					type: "button",
					onClick: onEnd,
					className: "mt-1 min-h-11 rounded-sm px-3 py-2 text-sm font-medium text-muted transition-colors duration-150 hover:text-fg",
					children: "End"
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				className: "mt-8 flex flex-1 flex-col",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(MetricLabel, { children: "Heading" }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-3 flex items-center gap-5",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Compass, {
							bearing: arrived ? 0 : metrics.heading.deg,
							dim: arrived
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "font-mono text-3xl leading-none font-medium tracking-tight tabular-nums text-fg",
							children: [arrived ? "—" : formatHeading(metrics.heading.deg), arrived ? null : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "ml-2 align-baseline text-lg font-normal text-muted",
								children: metrics.heading.cardinal
							})]
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(MetricLabel, {
						className: "mt-8",
						children: "Speed"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-1 font-mono text-3xl leading-none font-medium tracking-tight tabular-nums text-fg",
						children: [speed.value, /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "ml-2 align-baseline text-lg font-normal text-muted",
							children: speed.unit
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-auto flex flex-col pb-2 pt-6",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(MetricLabel, { children: "Delta" }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
								"aria-live": "polite",
								className: cn("mt-1 font-mono text-delta leading-none font-medium tracking-tight tabular-nums transition-colors duration-500", deltaColor),
								children: [delta.sign, delta.clock]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: cn("mt-3 text-sm font-medium uppercase tracking-label", deltaColor),
								children: arrived ? "you arrived" : delta.label
							})
						]
					})
				]
			}),
			session.demo ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "text-center text-xs tracking-wide text-faint",
				children: "Preview walk"
			}) : null
		]
	});
}
function Compass({ bearing, dim }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
		viewBox: "0 0 120 120",
		className: cn("size-24 shrink-0", dim ? "opacity-40" : ""),
		"aria-hidden": true,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "60",
				cy: "60",
				r: "54",
				fill: "none",
				stroke: "#2a2a2c",
				strokeWidth: "1.5"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("text", {
				x: "60",
				y: "18",
				textAnchor: "middle",
				fill: "#8e8c86",
				fontSize: "10",
				fontFamily: "Instrument Sans, sans-serif",
				children: "N"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("g", {
				style: {
					transform: `rotate(${bearing}deg)`,
					transformOrigin: "60px 60px"
				},
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("polygon", {
					points: "60,16 66,62 60,56 54,62",
					fill: "#f3f1ec"
				})
			})
		]
	});
}
function MetricLabel({ children, className }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: cn("text-xs font-medium uppercase tracking-label text-muted", className),
		children
	});
}
function remainingM(fix, dest) {
	return haversineM(fix, dest);
}
function headingToDest(fix, dest) {
	const deg = bearingDeg(fix, dest);
	return {
		deg,
		cardinal: cardinal(deg)
	};
}
function computeDelta(session, remaining, now) {
	return scheduleDeltaSec({
		startDistanceM: session.startDistanceM,
		remainingM: remaining,
		startAt: session.startAt,
		arriveBy: session.arriveBy,
		now
	});
}
function hasArrived(remaining) {
	return remaining <= 18;
}
var WATCH_OPTIONS = {
	enableHighAccuracy: true,
	maximumAge: 1e3,
	timeout: 12e3
};
function toFix(pos, last) {
	const { coords } = pos;
	let speed = coords.speed;
	if ((speed == null || speed < 0) && last) {
		const dt = (pos.timestamp - last.timestamp) / 1e3;
		if (dt > .4) {
			const dLat = coords.latitude - last.lat;
			const dLon = coords.longitude - last.lon;
			const m = Math.sqrt(dLat * dLat + dLon * dLon) * 111320 * Math.cos(coords.latitude * Math.PI / 180);
			speed = Math.max(0, m / dt);
		}
	}
	const next = {
		lat: coords.latitude,
		lon: coords.longitude,
		speedMps: speed == null || speed < 0 ? last?.speedMps ?? null : speed,
		accuracyM: coords.accuracy ?? null,
		timestamp: pos.timestamp
	};
	if (last && next.speedMps != null && last.speedMps != null) next.speedMps = last.speedMps * .65 + next.speedMps * .35;
	return next;
}
function useGeolocation(enabled) {
	const [status, setStatus] = (0, import_react.useState)("idle");
	const [fix, setFix] = (0, import_react.useState)(null);
	const [error, setError] = (0, import_react.useState)(null);
	const lastRef = (0, import_react.useRef)(null);
	const watchRef = (0, import_react.useRef)(null);
	const stop = (0, import_react.useCallback)(() => {
		if (watchRef.current != null && typeof navigator !== "undefined") {
			navigator.geolocation.clearWatch(watchRef.current);
			watchRef.current = null;
		}
	}, []);
	const start = (0, import_react.useCallback)(() => {
		if (typeof navigator === "undefined" || !navigator.geolocation) {
			setStatus("unavailable");
			setError("Location is not available in this browser.");
			return;
		}
		setStatus("requesting");
		setError(null);
		stop();
		watchRef.current = navigator.geolocation.watchPosition((pos) => {
			const next = toFix(pos, lastRef.current);
			lastRef.current = next;
			setFix(next);
			setStatus("live");
		}, (err) => {
			if (err.code === err.PERMISSION_DENIED) {
				setStatus("denied");
				setError("Location permission denied.");
			} else {
				setStatus("unavailable");
				setError(err.message || "Could not read GPS.");
			}
		}, WATCH_OPTIONS);
	}, [stop]);
	(0, import_react.useEffect)(() => {
		if (!enabled) {
			stop();
			return;
		}
		start();
		return stop;
	}, [
		enabled,
		start,
		stop
	]);
	return {
		status,
		fix,
		error,
		start,
		stop
	};
}
function useNow(intervalMs = 1e3, enabled = true) {
	const [now, setNow] = (0, import_react.useState)(() => Date.now());
	(0, import_react.useEffect)(() => {
		if (!enabled) return;
		const id = window.setInterval(() => setNow(Date.now()), intervalMs);
		return () => window.clearInterval(id);
	}, [enabled, intervalMs]);
	return now;
}
function useWakeLock(active) {
	(0, import_react.useEffect)(() => {
		if (!active || typeof navigator === "undefined") return;
		const nav = navigator;
		if (!nav.wakeLock) return;
		let released = false;
		let sentinel = null;
		const request = async () => {
			try {
				sentinel = await nav.wakeLock.request("screen");
			} catch {
				sentinel = null;
			}
		};
		request();
		const onVisible = () => {
			if (document.visibilityState === "visible" && !released) request();
		};
		document.addEventListener("visibilitychange", onVisible);
		return () => {
			released = true;
			document.removeEventListener("visibilitychange", onVisible);
			sentinel?.release();
		};
	}, [active]);
}
/** Walking distance in meters along streets. Null if the router is unavailable. */
async function walkDistanceM(from, to) {
	const url = `https://router.project-osrm.org/route/v1/foot/${from.lon},${from.lat};${to.lon},${to.lat}?overview=false`;
	const ctrl = new AbortController();
	const timer = setTimeout(() => ctrl.abort(), 4e3);
	try {
		const res = await fetch(url, { signal: ctrl.signal });
		if (!res.ok) return null;
		const meters = (await res.json()).routes?.[0]?.distance;
		return typeof meters === "number" && meters > 0 ? meters : null;
	} catch {
		return null;
	} finally {
		clearTimeout(timer);
	}
}
var UNITS_KEY = "ktp:units";
var RECENT_KEY = "ktp:recent";
var DEMO_DEST = {
	name: "Gantry Plaza State Park",
	area: "Long Island City",
	lat: 40.74551,
	lon: -73.95875
};
function loadUnits() {
	if (typeof window === "undefined") return "imperial";
	const stored = window.localStorage.getItem(UNITS_KEY);
	if (stored === "imperial" || stored === "metric") return stored;
	return detectUnits();
}
function loadRecent() {
	if (typeof window === "undefined") return [];
	try {
		const raw = window.localStorage.getItem(RECENT_KEY);
		if (!raw) return [];
		const parsed = JSON.parse(raw);
		return Array.isArray(parsed) ? parsed.slice(0, 6) : [];
	} catch {
		return [];
	}
}
function saveRecent(place) {
	const next = [place, ...loadRecent().filter((p) => p.name !== place.name)].slice(0, 6);
	window.localStorage.setItem(RECENT_KEY, JSON.stringify(next));
}
function demoStartFrom(dest) {
	return destinationPoint(dest, 188, 280);
}
function usePaceApp() {
	const [phase, setPhase] = (0, import_react.useState)("setup");
	const [units, setUnitsState] = (0, import_react.useState)("imperial");
	const [destination, setDestination] = (0, import_react.useState)(null);
	const [arriveBy, setArriveBy] = (0, import_react.useState)(null);
	const [session, setSession] = (0, import_react.useState)(null);
	const [demoFix, setDemoFix] = (0, import_react.useState)(null);
	const [recent, setRecent] = (0, import_react.useState)([]);
	const [gpsWanted, setGpsWanted] = (0, import_react.useState)(true);
	const [planMeters, setPlanMeters] = (0, import_react.useState)(null);
	const [planFromRoute, setPlanFromRoute] = (0, import_react.useState)(false);
	const [routeRemaining, setRouteRemaining] = (0, import_react.useState)(null);
	const lockedRef = (0, import_react.useRef)(false);
	const etaTouched = (0, import_react.useRef)(false);
	const planToken = (0, import_react.useRef)(0);
	const frozenDelta = (0, import_react.useRef)(null);
	const fixRef = (0, import_react.useRef)(null);
	const geo = useGeolocation(gpsWanted && (phase === "setup" || Boolean(session && !session.demo)));
	const now = useNow(1e3, phase !== "setup");
	useWakeLock(phase === "walk");
	(0, import_react.useEffect)(() => {
		setUnitsState(loadUnits());
		setRecent(loadRecent());
	}, []);
	const setUnits = (0, import_react.useCallback)((next) => {
		setUnitsState(next);
		window.localStorage.setItem(UNITS_KEY, next);
	}, []);
	const origin = geo.fix;
	const chooseDestination = (0, import_react.useCallback)((place, from = origin) => {
		setDestination(place);
		etaTouched.current = false;
		const crow = from ? haversineM(from, place) : 1200;
		setPlanFromRoute(false);
		setPlanMeters(crow);
		setArriveBy(roundUpToMinute(Date.now() + walkEstimateMs(Math.max(crow, 80))));
		if (!from) return;
		const token = ++planToken.current;
		walkDistanceM(from, place).then((meters) => {
			if (meters == null || token !== planToken.current || etaTouched.current) return;
			setPlanFromRoute(true);
			setPlanMeters(meters);
			setArriveBy(roundUpToMinute(Date.now() + walkEstimateMs(Math.max(meters, 80))));
		});
	}, [origin]);
	const bumpArriveBy = (0, import_react.useCallback)((deltaMin) => {
		etaTouched.current = true;
		setArriveBy((prev) => {
			const base = prev ?? Date.now() + 9e5;
			return Math.max(Date.now() + 6e4, base + deltaMin * 6e4);
		});
	}, []);
	const setArriveByInput = (0, import_react.useCallback)((value) => {
		const parsed = parseTimeInput(value);
		if (!parsed) return;
		etaTouched.current = true;
		setArriveBy(parsed);
	}, []);
	const beginSession = (0, import_react.useCallback)((opts) => {
		const crow = haversineM(opts.start, opts.dest);
		const startDistanceM = Math.max(opts.startDistanceM ?? crow, 30);
		const sess = {
			dest: opts.dest,
			start: opts.start,
			startDistanceM,
			startAt: Date.now(),
			arriveBy: Math.max(opts.arriveBy, Date.now() + 6e4),
			demo: opts.demo,
			routed: Boolean(opts.routed)
		};
		lockedRef.current = false;
		frozenDelta.current = null;
		setRouteRemaining(opts.routed ? startDistanceM : null);
		setSession(sess);
		setDestination(opts.dest);
		setArriveBy(sess.arriveBy);
		saveRecent(opts.dest);
		setRecent(loadRecent());
		if (opts.demo) {
			setDemoFix({
				...opts.start,
				speedMps: 1.72,
				accuracyM: 5,
				timestamp: Date.now()
			});
			setGpsWanted(false);
		} else {
			setDemoFix(null);
			setGpsWanted(true);
		}
		setPhase("walk");
	}, []);
	const startWalking = (0, import_react.useCallback)(() => {
		if (!destination || !arriveBy) return;
		const start = geo.fix;
		if (!start) return;
		const fallback = planMeters ?? haversineM(start, destination);
		beginSession({
			dest: destination,
			start,
			arriveBy,
			demo: false,
			startDistanceM: fallback,
			routed: planFromRoute
		});
	}, [
		arriveBy,
		beginSession,
		destination,
		geo.fix,
		planFromRoute,
		planMeters
	]);
	const startDemo = (0, import_react.useCallback)(() => {
		const dest = destination ?? DEMO_DEST;
		const start = demoStartFrom(dest);
		const dist = haversineM(start, dest);
		const arrive = Date.now() + walkEstimateMs(dist, .85);
		beginSession({
			dest,
			start,
			arriveBy: arrive,
			demo: true
		});
	}, [beginSession, destination]);
	(0, import_react.useEffect)(() => {
		if (phase !== "walk" || !session?.demo) return;
		const dest = session.dest;
		const id = window.setInterval(() => {
			setDemoFix((prev) => {
				if (!prev) return prev;
				if (haversineM(prev, dest) <= 18) return {
					...prev,
					...dest,
					speedMps: 0,
					timestamp: Date.now()
				};
				const t = Date.now() / 1e3;
				const speed = 1.72 + Math.sin(t / 3.2) * .18;
				const next = moveTowards(prev, dest, speed * .25);
				return {
					lat: next.lat,
					lon: next.lon,
					speedMps: speed,
					accuracyM: 5,
					timestamp: Date.now()
				};
			});
		}, 250);
		return () => window.clearInterval(id);
	}, [phase, session]);
	const liveFix = session?.demo ? demoFix : geo.fix;
	fixRef.current = liveFix;
	(0, import_react.useEffect)(() => {
		if (phase === "setup" || !session?.routed) return;
		let stop = false;
		const pull = async () => {
			const fix = fixRef.current;
			if (!fix) return;
			const meters = await walkDistanceM(fix, session.dest);
			if (!stop && meters != null) setRouteRemaining(meters);
		};
		pull();
		const id = window.setInterval(pull, 12e3);
		return () => {
			stop = true;
			window.clearInterval(id);
		};
	}, [phase, session]);
	const metrics = (0, import_react.useMemo)(() => {
		if (!session || !liveFix) return null;
		const crow = remainingM(liveFix, session.dest);
		const remaining = session.routed ? routeRemaining ?? crow : crow;
		const heading = headingToDest(liveFix, session.dest);
		const arrived = hasArrived(crow);
		const liveDelta = computeDelta(session, arrived ? 0 : remaining, now);
		if (arrived && frozenDelta.current == null) frozenDelta.current = liveDelta;
		return {
			remaining: arrived ? 0 : remaining,
			heading,
			deltaSec: arrived ? frozenDelta.current ?? liveDelta : liveDelta,
			arrived,
			speedMps: liveFix.speedMps ?? 0
		};
	}, [
		liveFix,
		now,
		routeRemaining,
		session
	]);
	(0, import_react.useEffect)(() => {
		if (phase !== "walk" || !metrics?.arrived || lockedRef.current) return;
		lockedRef.current = true;
		setPhase("arrived");
	}, [metrics?.arrived, phase]);
	const endSession = (0, import_react.useCallback)(() => {
		setPhase("setup");
		setSession(null);
		setDemoFix(null);
		setGpsWanted(true);
		setRouteRemaining(null);
		frozenDelta.current = null;
		lockedRef.current = false;
	}, []);
	return {
		phase,
		units,
		setUnits,
		destination,
		arriveBy,
		arriveByInput: arriveBy ? timeInputValue(arriveBy) : "",
		setArriveByInput,
		bumpArriveBy,
		chooseDestination,
		origin,
		geo,
		recent,
		planMeters,
		session,
		metrics,
		startWalking,
		startDemo,
		endSession,
		canStart: Boolean(destination && arriveBy && geo.fix)
	};
}
function Home() {
	const app = usePaceApp();
	if ((app.phase === "walk" || app.phase === "arrived") && app.session && app.metrics) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(WalkView, {
		session: app.session,
		metrics: app.metrics,
		units: app.units,
		phase: app.phase === "arrived" ? "arrived" : "walk",
		onEnd: app.endSession
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(SetupView, {
		units: app.units,
		setUnits: app.setUnits,
		destination: app.destination,
		origin: app.origin,
		geoStatus: app.geo.status,
		geoError: app.geo.error,
		requestGps: app.geo.start,
		arriveBy: app.arriveBy,
		arriveByInput: app.arriveByInput,
		setArriveByInput: app.setArriveByInput,
		bumpArriveBy: app.bumpArriveBy,
		chooseDestination: app.chooseDestination,
		recent: app.recent,
		planMeters: app.planMeters,
		canStart: app.canStart,
		onStart: app.startWalking,
		onDemo: app.startDemo
	});
}
//#endregion
export { Home as component };
