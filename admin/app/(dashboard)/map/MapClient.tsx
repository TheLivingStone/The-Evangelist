"use client";

import dynamic from "next/dynamic";
import type { GeoActivity, GeoChurch, GeoLive, GeoPost } from "@/lib/analytics";

// MapLibre touches `window`, so the map must never render on the server.
const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => (
    <div className="mapwrap">
      <div className="empty" style={{ paddingTop: 240 }}>
        Loading map…
      </div>
    </div>
  ),
});

export default function MapClient(props: {
  activity: GeoActivity[];
  churches: GeoChurch[];
  live: GeoLive[];
  posts: GeoPost[];
}) {
  return <MapView {...props} />;
}
