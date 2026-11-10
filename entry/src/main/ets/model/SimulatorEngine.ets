import { LatLng, distanceMeters, bearingDegrees } from './GeoUtils';

export enum SimMode {
  FIXED = 0,
  ROUTE = 1
}

export enum SimState {
  IDLE = 0,
  RUNNING = 1,
  PAUSED = 2,
  FINISHED = 3
}

export class SimSnapshot {
  latitude: number = 0;
  longitude: number = 0;
  bearing: number = 0;
  speedMs: number = 0;
  distanceM: number = 0;
  elapsedMs: number = 0;
  totalM: number = 0;
  progress: number = 0;
  state: SimState = SimState.IDLE;
}

/**
 * 在自身进程内按给定点位与速度推进模拟坐标，不依赖系统定位能力。
 * 速度单位统一为 m/s；speedJitterPct 为速度浮动百分比（0~100，表示 ±pct%）。
 */
export class SimulatorEngine {
  private points: LatLng[] = [];
  private segLengths: number[] = [];
  private totalM: number = 0;
  private segIndex: number = 0;
  private segOffset: number = 0;
  private movedM: number = 0;
  private elapsedMs: number = 0;
  private curLat: number = 0;
  private curLng: number = 0;
  private curBearing: number = 0;
  private curSpeedMs: number = 0;
  private state: SimState = SimState.IDLE;

  mode: SimMode = SimMode.FIXED;
  speedMs: number = 4.2;
  speedJitterPct: number = 0;
  loop: boolean = true;

  getState(): SimState {
    return this.state;
  }

  getPoints(): LatLng[] {
    return this.points;
  }

  getTotalDistance(): number {
    return this.totalM;
  }

  setPoints(points: LatLng[]): void {
    this.points = points.slice();
    this.rebuild();
    this.resetProgress();
  }

  private rebuild(): void {
    this.segLengths = [];
    this.totalM = 0;
    for (let i = 0; i + 1 < this.points.length; i++) {
      const d: number = distanceMeters(this.points[i], this.points[i + 1]);
      this.segLengths.push(d);
      this.totalM += d;
    }
  }

  private resetProgress(): void {
    this.segIndex = 0;
    this.segOffset = 0;
    this.movedM = 0;
    this.elapsedMs = 0;
    this.curBearing = 0;
    this.curSpeedMs = 0;
    this.state = SimState.IDLE;
    if (this.points.length > 0) {
      this.curLat = this.points[0].latitude;
      this.curLng = this.points[0].longitude;
      if (this.points.length > 1) {
        this.curBearing = bearingDegrees(this.points[0], this.points[1]);
      }
    }
  }

  start(): boolean {
    if (this.points.length === 0) {
      return false;
    }
    this.resetProgress();
    this.state = SimState.RUNNING;
    return true;
  }

  pause(): void {
    if (this.state === SimState.RUNNING) {
      this.state = SimState.PAUSED;
      this.curSpeedMs = 0;
    }
  }

  resume(): void {
    if (this.state === SimState.PAUSED) {
      this.state = SimState.RUNNING;
    }
  }

  stop(): void {
    this.resetProgress();
  }

  tick(deltaMs: number): void {
    if (this.state !== SimState.RUNNING || this.points.length === 0) {
      return;
    }
    this.elapsedMs += deltaMs;

    // 计算带浮动的瞬时速度（m/s）
    const jitter: number = this.speedJitterPct > 0
      ? (Math.random() * 2 - 1) * this.speedJitterPct / 100
      : 0;
    this.curSpeedMs = Math.max(0, this.speedMs * (1 + jitter));

    if (this.mode === SimMode.FIXED || this.points.length < 2 || this.totalM < 0.5) {
      this.curLat = this.points[0].latitude;
      this.curLng = this.points[0].longitude;
      return;
    }

    let advance: number = this.curSpeedMs * deltaMs / 1000;
    if (advance <= 0) {
      return;
    }
    if (!this.loop) {
      const remaining: number = this.totalM - this.movedM;
      if (advance > remaining) {
        advance = remaining;
      }
    }

    let guard: number = 0;
    while (advance > 0.0001 && guard < 10000) {
      guard++;
      const segLen: number = this.segLengths[this.segIndex];
      if (segLen < 0.0001) {
        this.nextSegment();
        if (this.state !== SimState.RUNNING) {
          break;
        }
        continue;
      }
      const remainInSeg: number = segLen - this.segOffset;
      if (advance < remainInSeg) {
        this.segOffset += advance;
        this.movedM += advance;
        advance = 0;
      } else {
        this.movedM += remainInSeg;
        advance -= remainInSeg;
        this.nextSegment();
        if (this.state !== SimState.RUNNING) {
          break;
        }
      }
    }
    this.updatePosition();
  }

  private nextSegment(): void {
    this.segIndex++;
    this.segOffset = 0;
    if (this.segIndex >= this.segLengths.length) {
      if (this.loop) {
        this.segIndex = 0;
      } else {
        this.segIndex = this.segLengths.length - 1;
        this.segOffset = this.segLengths[this.segIndex];
        this.state = SimState.FINISHED;
        this.curSpeedMs = 0;
        this.updatePosition();
      }
    }
  }

  private updatePosition(): void {
    if (this.segLengths.length === 0 || this.points.length < 2) {
      return;
    }
    const i: number = Math.min(this.segIndex, this.segLengths.length - 1);
    const a: LatLng = this.points[i];
    const b: LatLng = this.points[i + 1];
    const segLen: number = this.segLengths[i];
    const t: number = segLen > 0 ? this.segOffset / segLen : 0;
    const ratio: number = Math.max(0, Math.min(1, t));
    this.curLat = a.latitude + (b.latitude - a.latitude) * ratio;
    this.curLng = a.longitude + (b.longitude - a.longitude) * ratio;
    this.curBearing = bearingDegrees(a, b);
  }

  snapshot(): SimSnapshot {
    const s: SimSnapshot = new SimSnapshot();
    s.latitude = this.curLat;
    s.longitude = this.curLng;
    s.bearing = this.curBearing;
    s.speedMs = this.curSpeedMs;
    s.distanceM = this.movedM;
    s.elapsedMs = this.elapsedMs;
    s.totalM = this.totalM;
    s.state = this.state;
    if (this.totalM > 0.5) {
      s.progress = this.loop
        ? (this.movedM % this.totalM) / this.totalM
        : Math.min(1, this.movedM / this.totalM);
    }
    return s;
  }
}
