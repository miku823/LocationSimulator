import fs from 'fs';

// 生成一条北京天安门附近的螺旋轨迹，采样成 1000 点，间隔 1 秒，持续约 16 分钟
const centerLat = 39.9042;
const centerLng = 116.4074;

// 控制点（螺旋）
const controlPts = [];
for (let i = 0; i < 50; i++) {
  const angle = (i / 10) * Math.PI * 2;
  const r = 0.0005 * (1 + i * 0.05);
  controlPts.push({
    lat: centerLat + r * Math.cos(angle),
    lng: centerLng + r * Math.sin(angle)
  });
}

function distMeters(a, b) {
  const dLat = (b.lat - a.lat) * 111320;
  const dLng = (b.lng - a.lng) * 111320 * Math.cos(a.lat * Math.PI / 180);
  return Math.sqrt(dLat * dLat + dLng * dLng);
}

const segLen = [];
let total = 0;
for (let i = 0; i + 1 < controlPts.length; i++) {
  const d = distMeters(controlPts[i], controlPts[i + 1]);
  segLen.push(d);
  total += d;
}

const speedMs = 3.0;
const intervalSec = 1;
const durationSec = total / speedMs;
const sampleCount = Math.min(1000, Math.ceil(durationSec / intervalSec) + 1);

const out = [];
for (let k = 0; k < sampleCount; k++) {
  const tRatio = durationSec > 0 ? (k * intervalSec) / durationSec : 0;
  let distAlong = tRatio * total;
  if (distAlong > total) distAlong = total;

  let acc = 0;
  let segIdx = 0;
  let segT = 0;
  for (let i = 0; i < segLen.length; i++) {
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
  const a = controlPts[segIdx];
  const b = controlPts[Math.min(segIdx + 1, controlPts.length - 1)];
  const lat = a.lat + (b.lat - a.lat) * segT;
  const lng = a.lng + (b.lng - a.lng) * segT;
  const dLat = (b.lat - a.lat);
  const dLng = (b.lng - a.lng);
  let bearing = (Math.atan2(dLng, dLat) * 180 / Math.PI + 360) % 360;
  out.push({ lat, lng, speedMs, bearing });
}

out[0].lat = controlPts[0].lat;
out[0].lng = controlPts[0].lng;
out[out.length - 1].lat = controlPts[controlPts.length - 1].lat;
out[out.length - 1].lng = controlPts[controlPts.length - 1].lng;

let body = '';
for (const p of out) {
  const b = ((p.bearing % 360) + 360) % 360;
  body += `      <trkpt lat="${p.lat.toFixed(7)}" lon="${p.lng.toFixed(7)}">\n`;
  body += `        <ele>10.0</ele>\n`;
  body += `        <speed>${p.speedMs.toFixed(2)}</speed>\n`;
  body += `        <direction>${b.toFixed(2)}</direction>\n`;
  body += `      </trkpt>\n`;
}

const xml = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="LocationSimulator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><name>Test Long Track</name></metadata>
  <trk>
    <trkseg>
${body}    </trkseg>
  </trk>
</gpx>
`;

fs.writeFileSync('./test_long_track.gpx', xml);
console.log('采样点数:', out.length);
console.log('GPX 大小:', xml.length, '字节');
console.log('起点:', out[0].lat.toFixed(6), out[0].lng.toFixed(6));
console.log('终点:', out[out.length - 1].lat.toFixed(6), out[out.length - 1].lng.toFixed(6));
console.log('预计持续时长:', Math.round(out.length * intervalSec), '秒 =', Math.round(out.length * intervalSec / 60), '分钟');
