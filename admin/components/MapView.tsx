"use client";

import { useEffect, useRef, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { C } from "./charts/theme";
import type { GeoActivity, GeoChurch, GeoLive, GeoPost } from "@/lib/analytics";

// Dark vector basemap, no API token required (CARTO's public dark style).
const DARK_STYLE = "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json";

type Props = {
  activity: GeoActivity[];
  churches: GeoChurch[];
  live: GeoLive[];
  posts: GeoPost[];
};

function avgCenter(all: { lat: number; lng: number }[]): [number, number] {
  if (!all.length) return [0, 20]; // world-ish default
  const lat = all.reduce((a, b) => a + b.lat, 0) / all.length;
  const lng = all.reduce((a, b) => a + b.lng, 0) / all.length;
  return [lng, lat];
}

export default function MapView({ activity, churches, live, posts }: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<maplibregl.Marker[]>([]);
  const [ready, setReady] = useState(false);
  const [layers, setLayers] = useState({
    heatmap: true,
    churches: true,
    live: true,
    posts: false,
  });

  // Init map once.
  useEffect(() => {
    if (!ref.current || mapRef.current) return;
    const all = [...activity, ...churches, ...live, ...posts];
    const center = avgCenter(all);
    const map = new maplibregl.Map({
      container: ref.current,
      style: DARK_STYLE,
      center,
      zoom: all.length ? 9 : 1.4,
      attributionControl: { compact: true },
    });
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-left");
    mapRef.current = map;
    map.on("load", () => {
      // Heatmap source from activity points.
      map.addSource("activity", {
        type: "geojson",
        data: {
          type: "FeatureCollection",
          features: activity.map((a) => ({
            type: "Feature",
            geometry: { type: "Point", coordinates: [a.lng, a.lat] },
            properties: { type: a.type },
          })),
        },
      });
      map.addLayer({
        id: "activity-heat",
        type: "heatmap",
        source: "activity",
        paint: {
          "heatmap-weight": 1,
          "heatmap-intensity": 1.1,
          "heatmap-radius": 28,
          "heatmap-opacity": 0.85,
          "heatmap-color": [
            "interpolate", ["linear"], ["heatmap-density"],
            0, "rgba(0,0,0,0)",
            0.2, "rgba(91,141,239,0.4)",
            0.4, "rgba(255,138,43,0.6)",
            0.7, "rgba(255,107,0,0.85)",
            1, "rgba(255,107,0,1)",
          ],
        },
      });
      setReady(true);
    });
    return () => {
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Toggle heatmap visibility.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;
    if (map.getLayer("activity-heat")) {
      map.setLayoutProperty("activity-heat", "visibility", layers.heatmap ? "visible" : "none");
    }
  }, [layers.heatmap, ready]);

  // (Re)draw HTML markers for churches / live / posts when toggles change.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !ready) return;
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    const add = (lng: number, lat: number, color: string, popupHtml?: string, size = 12) => {
      const el = document.createElement("div");
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      el.style.borderRadius = "999px";
      el.style.background = color;
      el.style.border = "1.5px solid rgba(255,255,255,0.85)";
      el.style.boxShadow = `0 0 8px ${color}`;
      el.style.cursor = popupHtml ? "pointer" : "default";
      const marker = new maplibregl.Marker({ element: el }).setLngLat([lng, lat]);
      if (popupHtml) {
        marker.setPopup(new maplibregl.Popup({ offset: 12, closeButton: false }).setHTML(popupHtml));
      }
      marker.addTo(map);
      markersRef.current.push(marker);
    };

    if (layers.churches) {
      for (const c of churches) {
        const color = c.is_verified ? C.green : c.claim_status === "pending" ? C.accent : C.muted;
        add(
          c.lng,
          c.lat,
          color,
          `<strong>${escapeHtml(c.name)}</strong><br/>${escapeHtml(c.city || "")}<br/>${
            c.is_verified ? "✅ Verified" : (c.claim_status || "unclaimed")
          }`,
          13,
        );
      }
    }
    if (layers.live) {
      for (const l of live) add(l.lng, l.lat, C.blue, undefined, 11);
    }
    if (layers.posts) {
      for (const p of posts) add(p.lng, p.lat, C.purple, `Post · ${escapeHtml(p.type)}`, 10);
    }
  }, [layers.churches, layers.live, layers.posts, ready, churches, live, posts]);

  return (
    <div className="mapwrap">
      <div ref={ref} style={{ position: "absolute", inset: 0 }} />
      <div className="map-layers">
        <Toggle
          checked={layers.heatmap}
          onChange={(v) => setLayers((s) => ({ ...s, heatmap: v }))}
          color={C.accent}
          label={`Activity heatmap (${activity.length})`}
        />
        <Toggle
          checked={layers.churches}
          onChange={(v) => setLayers((s) => ({ ...s, churches: v }))}
          color={C.green}
          label={`Churches (${churches.length})`}
        />
        <Toggle
          checked={layers.live}
          onChange={(v) => setLayers((s) => ({ ...s, live: v }))}
          color={C.blue}
          label={`Live evangelists (${live.length})`}
        />
        <Toggle
          checked={layers.posts}
          onChange={(v) => setLayers((s) => ({ ...s, posts: v }))}
          color={C.purple}
          label={`Located posts (${posts.length})`}
        />
      </div>
    </div>
  );
}

function Toggle({
  checked,
  onChange,
  color,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  color: string;
  label: string;
}) {
  return (
    <label>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span className="map-legend-dot" style={{ background: color }} />
      {label}
    </label>
  );
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string),
  );
}
