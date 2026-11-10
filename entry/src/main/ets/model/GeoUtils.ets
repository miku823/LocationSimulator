export interface LatLng {
  latitude: number;
  longitude: number;
}

const EARTH_RADIUS_M: number = 6371008.8;

export function toRadians(deg: number): number {
  return deg * Math.PI / 180;
}

export function toDegrees(rad: number): number {
  return rad * 180 / Math.PI;
}

export function distanceMeters(a: LatLng, b: LatLng): number {
  const lat1: number = toRadians(a.latitude);
  const lat2: number = toRadians(b.latitude);
  const dLat: number = lat2 - lat1;
  const dLng: number = toRadians(b.longitude - a.longitude);
  const h: number = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function bearingDegrees(a: LatLng, b: LatLng): number {
  const lat1: number = toRadians(a.latitude);
  const lat2: number = toRadians(b.latitude);
  const dLng: number = toRadians(b.longitude - a.longitude);
  const y: number = Math.sin(dLng) * Math.cos(lat2);
  const x: number = Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  const deg: number = toDegrees(Math.atan2(y, x));
  return (deg + 360) % 360;
}

export function formatLatLng(lat: number, lng: number): string {
  return lat.toFixed(6) + ', ' + lng.toFixed(6);
}

export function formatDistance(m: number): string {
  if (m < 1000) {
    return Math.round(m) + ' m';
  }
  return (m / 1000).toFixed(2) + ' km';
}

export function formatDuration(ms: number): string {
  const total: number = Math.floor(ms / 1000);
  const h: number = Math.floor(total / 3600);
  const m: number = Math.floor((total % 3600) / 60);
  const s: number = total % 60;
  const mm: string = m < 10 ? '0' + m.toString() : m.toString();
  const ss: string = s < 10 ? '0' + s.toString() : s.toString();
  if (h > 0) {
    return h.toString() + ':' + mm + ':' + ss;
  }
  return mm + ':' + ss;
}

export function formatSpeedMs(ms: number): string {
  return ms.toFixed(1) + ' m/s';
}

export function compassLabel(deg: number): string {
  const names: string[] = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
  const idx: number = Math.round(((deg % 360) + 360) % 360 / 45) % 8;
  return names[idx];
}
