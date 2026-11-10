import { LatLng, distanceMeters, bearingDegrees } from './GeoUtils';

export interface SamplePoint {
  lat: number;
  lng: number;
  speedMs: number;
  bearing: number;
}

/**
 * 将路径点序列化为 GPX 1.1 格式（含 speed + direction），
 * 供 HarmonyOS 7.0 testhelper set-mocked-locations 使用。
 */
export class GpxBuilder {
  private samples: SamplePoint[];
  private ele: number = 10;

  constructor(samples: SamplePoint[]) {
    if (samples.length === 0) {
      throw new Error('GpxBuilder: empty samples');
    }
    this.samples = samples;
  }

  setElevation(e: number): void {
    this.ele = e;
  }

  toXml(): string {
    let body: string = '';
    for (let i: number = 0; i < this.samples.length; i++) {
      const p: SamplePoint = this.samples[i];
      const s: number = Math.max(0, p.speedMs);
      const b: number = ((p.bearing % 360) + 360) % 360;
      body +=
        '      <trkpt lat="' + p.lat.toFixed(7) +
        '" lon="' + p.lng.toFixed(7) + '">\n' +
        '        <ele>' + this.ele.toFixed(1) + '</ele>\n' +
        '        <speed>' + s.toFixed(2) + '</speed>\n' +
        '        <direction>' + b.toFixed(2) + '</direction>\n' +
        '      </trkpt>\n';
    }
    return '<?xml version="1.0" encoding="UTF-8"?>\n' +
      '<gpx version="1.1" creator="LocationSimulator" xmlns="http://www.topografix.com/GPX/1/1">\n' +
      '  <metadata><name>LocationSimulator Track</name></metadata>\n' +
      '  <trk>\n' +
      '    <trkseg>\n' +
      body +
      '    </trkseg>\n' +
      '  </trk>\n' +
      '</gpx>\n';
  }

  static MAX_POINTS: number = 1000;
}

/**
 * 按速度和间隔采样路径，生成 GpxBuilder 可用的 SamplePoint 数组。
 */
export function sampleTrack(
  points: LatLng[],
  speedMs: number,
  intervalSec: number
): SamplePoint[] {
  if (points.length < 2) {
    const p: LatLng = points[0];
    const out: SamplePoint[] = [];
    out.push({ lat: p.latitude, lng: p.longitude, speedMs: 0, bearing: 0 });
    return out;
  }

  const intervalMs: number = Math.max(1, intervalSec) * 1000;
  const segLen: number[] = [];
  let total: number = 0;
  for (let i: number = 0; i + 1 < points.length; i++) {
    const d: number = distanceMeters(points[i], points[i + 1]);
    segLen.push(d);
    total += d;
  }
  const durationSec: number = speedMs > 0 ? total / speedMs : 0;

  let sampleCount: number = Math.ceil(durationSec / intervalSec) + 1;
  if (sampleCount > GpxBuilder.MAX_POINTS) {
    sampleCount = GpxBuilder.MAX_POINTS;
  }
  if (sampleCount < 2) {
    sampleCount = 2;
  }

  const out: SamplePoint[] = [];
  for (let k: number = 0; k < sampleCount; k++) {
    const tRatio: number = durationSec > 0 ? k * intervalSec / durationSec : 0;
    let distAlong: number = tRatio * total;
    if (distAlong > total) {
      distAlong = total;
    }
    let acc: number = 0;
    let segIdx: number = 0;
    let segT: number = 0;
    for (let i: number = 0; i < segLen.length; i++) {
      if (acc + segLen[i] >= distAlong) {
        segIdx = i;
        segT = segLen[i] > 0 ? (distAlong - acc) / segLen[i] : 0;
        break;
      }
      acc += segLen[i];
      if (i === segLen.length - 1) {
        segIdx = i;
        segT = 1;
      }
    }
    const a: LatLng = points[segIdx];
    const b: LatLng = points[Math.min(segIdx + 1, points.length - 1)];
    const lat: number = a.latitude + (b.latitude - a.latitude) * segT;
    const lng: number = a.longitude + (b.longitude - a.longitude) * segT;
    out.push({
      lat: lat,
      lng: lng,
      speedMs: speedMs,
      bearing: bearingDegrees(a, b)
    });
  }

  if (out.length > 0) {
    out[0].lat = points[0].latitude;
    out[0].lng = points[0].longitude;
    out[out.length - 1].lat = points[points.length - 1].latitude;
    out[out.length - 1].lng = points[points.length - 1].longitude;
    out[out.length - 1].bearing = out.length > 1 ? out[out.length - 2].bearing : 0;
  }

  return out;
}
