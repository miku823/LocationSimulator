import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { geoLocationManager } from '@kit.LocationKit';
import {
  LatLng,
  distanceMeters,
  formatDistance,
  formatDuration,
  formatLatLng,
  formatSpeedMs,
  compassLabel
} from '../model/GeoUtils';
import { SimMode, SimState, SimSnapshot, SimulatorEngine } from '../model/SimulatorEngine';
import { CityPreset, popularCities, searchCities } from '../model/Cities';
import { RouteMeta, listRoutes, saveRoute, getRoutePoints, deleteRoute } from '../model/RouteStore';
import { BackgroundRunner } from '../service/BackgroundRunner';
import { LocationBroadcaster } from '../service/LocationBroadcaster';
import { GpxExporter, GpxResult } from '../service/GpxExporter';

const C_BG: string = '#0B0F14';
const C_CARD: string = '#121A24';
const C_SUNKEN: string = '#0C141C';
const C_LINE: string = '#1E2A38';
const C_TEXT: string = '#E7EEF7';
const C_SUB: string = '#8298AE';
const C_ACCENT: string = '#38BDF8';
const C_GREEN: string = '#22C55E';
const C_AMBER: string = '#F59E0B';
const C_RED: string = '#EF4444';

interface JsPoint {
  lat: number;
  lng: number;
}

type PickHandler = (lat: number, lng: number) => void;
type RectHandler = (lat1: number, lng1: number, lat2: number, lng2: number) => void;

/**
 * 注入 WebView 的桥接对象，供 map.html 回调点位与框选结果。
 */
class MapBridge {
  private pickHandler: PickHandler;
  private rectHandler: RectHandler;

  constructor(pickHandler: PickHandler, rectHandler: RectHandler) {
    this.pickHandler = pickHandler;
    this.rectHandler = rectHandler;
  }

  onPick(lat: number, lng: number): void {
    this.pickHandler(lat, lng);
  }

  onRect(lat1: number, lng1: number, lat2: number, lng2: number): void {
    this.rectHandler(lat1, lng1, lat2, lng2);
  }
}

@Entry
@Component
struct Index {
  @State points: LatLng[] = [];
  @State mode: SimMode = SimMode.FIXED;
  @State mapMode: string = 'pick';
  @State simState: SimState = SimState.IDLE;
  @State speedMs: number = 4.2;
  @State speedJitterPct: number = 0;
  @State curSpeedMs: number = 0;
  @State loop: boolean = true;
  @State bgEnabled: boolean = false;
  @State bgActive: boolean = false;
  @State broadcastEnabled: boolean = false;
  @State broadcastPort: number = 39527;
  @State broadcastRunning: boolean = false;
  @State systemMockActive: boolean = false;
  @State mockIntervalSec: number = 1;
  @State mockGpxInfo: string = '';
  @State sysLocInfo: string = '';
  @State curLat: number = 39.9042;
  @State curLng: number = 116.4074;
  @State curBearing: number = 0;
  @State distanceM: number = 0;
  @State elapsedMs: number = 0;
  @State progressVal: number = 0;
  @State hasRect: boolean = false;
  @State rectInfo: string = '';
  @State lonText: string = '';
  @State latText: string = '';
  @State mapReady: boolean = false;
  @State cityQuery: string = '';
  @State cityResults: CityPreset[] = popularCities();
  @State savedRoutes: RouteMeta[] = [];

  private engine: SimulatorEngine = new SimulatorEngine();
  private runner: BackgroundRunner = new BackgroundRunner();
  private broadcaster: LocationBroadcaster = new LocationBroadcaster();
  private gpxExporter: GpxExporter = new GpxExporter();
  private controller: webview.WebviewController = new webview.WebviewController();
  private timerId: number = -1;
  private lastTick: number = 0;
  private pageVisible: boolean = true;
  private rectMinLat: number = 0;
  private rectMaxLat: number = 0;
  private rectMinLng: number = 0;
  private rectMaxLng: number = 0;
  private bridge: MapBridge = new MapBridge(
    (lat: number, lng: number): void => this.handlePick(lat, lng),
    (lat1: number, lng1: number, lat2: number, lng2: number): void =>
      this.handleRect(lat1, lng1, lat2, lng2));

  // ---------- 地图桥接 ----------

  private handlePick(lat: number, lng: number): void {
    if (!this.isValidLatLng(lat, lng)) {
      return;
    }
    const arr: LatLng[] = this.points.slice();
    arr.push({ latitude: lat, longitude: lng });
    this.applyPoints(arr);
  }

  private handleRect(lat1: number, lng1: number, lat2: number, lng2: number): void {
    if (!this.isValidLatLng(lat1, lng1) || !this.isValidLatLng(lat2, lng2)) {
      return;
    }
    this.rectMinLat = Math.min(lat1, lat2);
    this.rectMaxLat = Math.max(lat1, lat2);
    this.rectMinLng = Math.min(lng1, lng2);
    this.rectMaxLng = Math.max(lng1, lng2);
    const midLat: number = (this.rectMinLat + this.rectMaxLat) / 2;
    const midLng: number = (this.rectMinLng + this.rectMaxLng) / 2;
    const width: number = distanceMeters(
      { latitude: midLat, longitude: this.rectMinLng },
      { latitude: midLat, longitude: this.rectMaxLng });
    const height: number = distanceMeters(
      { latitude: this.rectMinLat, longitude: midLng },
      { latitude: this.rectMaxLat, longitude: midLng });
    this.rectInfo = formatDistance(width) + ' × ' + formatDistance(height) +
      ' · 中心 ' + formatLatLng(midLat, midLng);
    this.hasRect = true;
  }

  private isValidLatLng(lat: number, lng: number): boolean {
    return lat >= -85 && lat <= 85 && lng >= -180 && lng <= 180;
  }

  // ---------- 点位管理 ----------

  private applyPoints(points: LatLng[]): void {
    if (this.simState === SimState.RUNNING || this.simState === SimState.PAUSED) {
      this.stopSimulation();
      this.toast('点位已更新，模拟已重置');
    }
    this.points = points;
    this.engine.setPoints(points);
    this.syncStats();
    this.pushPoints();
  }

  private addPoint(lat: number, lng: number, recenter: boolean): void {
    if (!this.isValidLatLng(lat, lng)) {
      this.toast('坐标超出有效范围');
      return;
    }
    const arr: LatLng[] = this.points.slice();
    arr.push({ latitude: lat, longitude: lng });
    this.points = arr;
    this.engine.setPoints(arr);
    this.syncStats();
    this.pushPoints();
    if (recenter) {
      this.runJs('window.mapApi.center(' + lat + ',' + lng + ',15)');
    }
  }

  private removePoint(index: number): void {
    const arr: LatLng[] = this.points.slice();
    if (index < 0 || index >= arr.length) {
      return;
    }
    arr.splice(index, 1);
    this.applyPoints(arr);
  }

  private clearPoints(): void {
    this.stopSimulation();
    this.applyPoints([]);
    this.runJs('window.mapApi.setPoints([])');
  }

  private pushPoints(): void {
    if (!this.mapReady) {
      return;
    }
    const arr: JsPoint[] = [];
    for (let i = 0; i < this.points.length; i++) {
      arr.push({ lat: this.points[i].latitude, lng: this.points[i].longitude });
    }
    this.runJs('window.mapApi.setPoints(' + JSON.stringify(arr) + ')');
  }

  // ---------- 框选 ----------

  private takeRectCenter(): void {
    const lat: number = (this.rectMinLat + this.rectMaxLat) / 2;
    const lng: number = (this.rectMinLng + this.rectMaxLng) / 2;
    this.addPoint(lat, lng, false);
    this.clearRect();
  }

  private takeRectRandom(): void {
    const lat: number = this.rectMinLat + Math.random() * (this.rectMaxLat - this.rectMinLat);
    const lng: number = this.rectMinLng + Math.random() * (this.rectMaxLng - this.rectMinLng);
    this.addPoint(lat, lng, false);
    this.runJs('window.mapApi.setPin(' + lat + ',' + lng + ')');
    this.clearRect();
  }

  /**
   * 在框选区域内按 2×3 蛇形网格生成 6 个随机点，组成一条完整路径。
   */
  private takeRectPath(): void {
    if (!this.hasRect) {
      this.toast('请先在地图上拖拽框选区域');
      return;
    }
    const latSpan: number = this.rectMaxLat - this.rectMinLat;
    const lngSpan: number = this.rectMaxLng - this.rectMinLng;
    if (latSpan < 0.0005 || lngSpan < 0.0005) {
      this.toast('框选区域太小，无法生成路径');
      return;
    }
    const rows: number = 2;
    const cols: number = 3;
    const cellLat: number = latSpan / rows;
    const cellLng: number = lngSpan / cols;
    const arr: LatLng[] = [];
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const col: number = (r % 2 === 0) ? c : (cols - 1 - c);
        const lat: number = this.rectMinLat + cellLat * (r + 0.2 + Math.random() * 0.6);
        const lng: number = this.rectMinLng + cellLng * (col + 0.2 + Math.random() * 0.6);
        arr.push({ latitude: lat, longitude: lng });
      }
    }
    this.applyPoints(arr);
    this.setMode(SimMode.ROUTE);
    const midLat: number = (this.rectMinLat + this.rectMaxLat) / 2;
    const midLng: number = (this.rectMinLng + this.rectMaxLng) / 2;
    const span: number = Math.max(latSpan, lngSpan);
    let zoom: number = 15;
    if (span > 0.2) {
      zoom = 12;
    } else if (span > 0.05) {
      zoom = 13;
    } else if (span > 0.01) {
      zoom = 14;
    }
    this.runJs('window.mapApi.center(' + midLat + ',' + midLng + ',' + zoom + ')');
    this.toast('已生成框内 6 点路径，可保存或直接开始模拟');
  }

  private clearRect(): void {
    this.hasRect = false;
    this.rectInfo = '';
    this.runJs('window.mapApi.clearRect()');
  }

  // ---------- 路线存档 ----------

  private pad2(n: number): string {
    return (n < 10 ? '0' : '') + n.toString();
  }

  private refreshSaved(): void {
    try {
      this.savedRoutes = listRoutes(this.hostContext());
    } catch (err) {
      this.savedRoutes = [];
    }
  }

  private saveCurrentRoute(): void {
    if (this.points.length === 0) {
      this.toast('当前没有点位可保存');
      return;
    }
    const d: Date = new Date();
    const name: string = '路线 ' + this.pad2(d.getMonth() + 1) + '-' + this.pad2(d.getDate()) +
      ' ' + this.pad2(d.getHours()) + ':' + this.pad2(d.getMinutes());
    try {
      saveRoute(this.hostContext(), name, this.points);
      this.refreshSaved();
      this.toast('已保存 ' + this.points.length + ' 个点位');
    } catch (err) {
      this.toast('保存失败，请重试');
    }
  }

  private loadRoute(meta: RouteMeta): void {
    const pts: LatLng[] = getRoutePoints(this.hostContext(), meta.name);
    if (pts.length === 0) {
      this.toast('存档数据为空，已清除');
      this.deleteRouteByName(meta);
      return;
    }
    this.applyPoints(pts);
    this.setMode(pts.length >= 2 ? SimMode.ROUTE : SimMode.FIXED);
    const first: LatLng = pts[0];
    this.runJs('window.mapApi.center(' + first.latitude + ',' + first.longitude + ',14)');
    this.toast('已载入 ' + meta.name + '（' + pts.length + ' 个点）');
  }

  private deleteRouteByName(meta: RouteMeta): void {
    try {
      deleteRoute(this.hostContext(), meta.name);
      this.refreshSaved();
      this.toast('已删除 ' + meta.name);
    } catch (err) {
      this.toast('删除失败');
    }
  }

  // ---------- 模拟控制 ----------

  private startSimulation(): void {
    if (this.points.length === 0) {
      this.toast('请先在地图上选择至少一个点位');
      return;
    }
    if (this.mode === SimMode.ROUTE && this.points.length < 2) {
      this.toast('轨迹模式至少需要 2 个点位');
      return;
    }
    this.engine.mode = this.mode;
    this.engine.speedMs = this.speedMs;
    this.engine.speedJitterPct = this.speedJitterPct;
    this.engine.loop = this.loop;
    if (!this.engine.start()) {
      return;
    }
    if (this.broadcastEnabled) {
      this.broadcaster.start(this.broadcastPort).then(() => {
        this.broadcastRunning = true;
      }).catch(() => {
        this.broadcastRunning = false;
        this.toast('广播启动失败，请检查端口');
      });
    }
    this.startTimer();
    this.syncStats();
    this.toast(this.mode === SimMode.FIXED ? '定点模拟已开始' : '轨迹模拟已开始');
  }

  private stopSimulation(): void {
    this.stopTimer();
    this.engine.stop();
    this.broadcaster.stop().then(() => {
      this.broadcastRunning = false;
    });
    this.syncStats();
    this.runJs('window.mapApi.clearSim()');
  }

  private onPrimaryAction(): void {
    if (this.simState === SimState.RUNNING) {
      this.engine.pause();
      this.stopTimer();
      this.syncStats();
      this.toast('已暂停');
      return;
    }
    if (this.simState === SimState.PAUSED) {
      this.engine.resume();
      this.startTimer();
      this.syncStats();
      this.toast('继续模拟');
      return;
    }
    this.startSimulation();
  }

  private primaryLabel(): string {
    if (this.simState === SimState.RUNNING) {
      return '暂停';
    }
    if (this.simState === SimState.PAUSED) {
      return '继续';
    }
    if (this.simState === SimState.FINISHED) {
      return '重新开始';
    }
    return '开始模拟';
  }

  private startTimer(): void {
    if (this.timerId !== -1) {
      return;
    }
    this.lastTick = Date.now();
    this.timerId = setInterval(() => {
      const now: number = Date.now();
      let dt: number = now - this.lastTick;
      this.lastTick = now;
      if (dt > 3000) {
        dt = 3000;
      }
      this.engine.tick(dt);
      this.syncStats();
      if (this.engine.getState() === SimState.FINISHED) {
        this.stopTimer();
        this.toast('轨迹模拟完成');
      }
    }, 500);
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private syncStats(): void {
    const snap: SimSnapshot = this.engine.snapshot();
    this.curLat = snap.latitude;
    this.curLng = snap.longitude;
    this.curBearing = snap.bearing;
    this.curSpeedMs = snap.speedMs;
    this.distanceM = snap.distanceM;
    this.elapsedMs = snap.elapsedMs;
    this.progressVal = Math.round(snap.progress * 100);
    this.simState = snap.state;
    if (snap.state === SimState.RUNNING) {
      this.runJs('window.mapApi.setSim(' + snap.latitude.toFixed(6) + ',' +
        snap.longitude.toFixed(6) + ')');
      if (this.broadcastRunning) {
        this.broadcaster.tick(snap.latitude, snap.longitude, snap.speedMs, snap.bearing);
      }
    }
  }

  private setSpeedMs(value: number): void {
    this.speedMs = value;
    this.engine.speedMs = value;
  }

  private setJitter(value: number): void {
    this.speedJitterPct = value;
    this.engine.speedJitterPct = value;
  }

  private setMode(mode: SimMode): void {
    if (this.mode === mode) {
      return;
    }
    if (this.simState === SimState.RUNNING || this.simState === SimState.PAUSED) {
      this.stopSimulation();
    }
    this.mode = mode;
    this.engine.mode = mode;
    this.engine.setPoints(this.points);
    this.syncStats();
  }

  private setMapMode(mode: string): void {
    this.mapMode = mode;
    this.runJs("window.mapApi.setMode('" + mode + "')");
  }

  private toggleLoop(isOn: boolean): void {
    this.loop = isOn;
    this.engine.loop = isOn;
  }

  // ---------- 坐标广播 ----------

  private async toggleBroadcast(isOn: boolean): Promise<void> {
    this.broadcastEnabled = isOn;
    if (!isOn) {
      await this.broadcaster.stop();
      this.broadcastRunning = false;
      this.toast('坐标广播已关闭');
      return;
    }
    // 模拟正在运行时即时启动广播
    if (this.simState === SimState.RUNNING || this.simState === SimState.PAUSED) {
      try {
        await this.broadcaster.start(this.broadcastPort);
        this.broadcastRunning = true;
        this.toast('坐标广播已开启：' + this.broadcastPort.toString());
      } catch (err) {
        this.broadcastEnabled = false;
        this.broadcastRunning = false;
        this.toast('广播启动失败，请检查端口');
      }
    } else {
      this.toast('开始模拟后将自动广播');
    }
  }

  private onPortChange(value: string): void {
    const p: number = Number(value);
    if (Number.isFinite(p) && p >= 1 && p <= 65535) {
      this.broadcastPort = Math.round(p);
    }
  }

  // ---------- 系统级 GPS 模拟（testhelper GPX 通道） ----------

  /**
   * 将当前路径点导出 GPX → 广播给 PC 端 → PC 调 testhelper enable + set-mocked-locations。
   */
  private enableSystemMock(): void {
    if (this.points.length < 2) {
      this.toast('至少需要 2 个轨迹点才能启用系统模拟');
      return;
    }
    const ctx: common.UIAbilityContext = this.hostContext();
    const speedForGpx: number = this.speedMs > 0 ? this.speedMs : 4.2;
    let gpxResult: GpxResult;
    try {
      gpxResult = this.gpxExporter.exportToFile(ctx, this.points, speedForGpx, this.mockIntervalSec);
    } catch (err) {
      this.toast('GPX 写入失败：' + (err as Error).message);
      return;
    }

    // 必须先启用广播通道，否则 PC 端收不到 gpxReady 消息
    if (!this.broadcastRunning) {
      this.broadcastEnabled = true;
      this.broadcaster.start(this.broadcastPort).then(() => {
        this.broadcastRunning = true;
        this.broadcastSystemMock(gpxResult);
      }).catch(() => {
        this.toast('广播启动失败，系统模拟不可用');
      });
    } else {
      this.broadcastSystemMock(gpxResult);
    }
  }

  private broadcastSystemMock(gpxResult: GpxResult): void {
    this.systemMockActive = true;
    this.mockGpxInfo = gpxResult.count.toString() + ' 点 · 间隔 ' + this.mockIntervalSec.toString() +
      's · GPX ' + gpxResult.path;
    this.broadcaster.gpxReady(gpxResult.path, gpxResult.count, this.mockIntervalSec,
      this.speedMs, this.mode === SimMode.ROUTE ? 'route' : 'fixed');
    this.toast('GPX 已导出，请 PC 端桥接脚本接收并调用 testhelper');
  }

  /** 通知 PC 端调用 testhelper disable-location-mock 恢复真实 GPS */
  private async disableSystemMock(): Promise<void> {
    this.broadcaster.gpxDone();
    this.systemMockActive = false;
    this.mockGpxInfo = '';
    this.toast('已请求 PC 端停止系统模拟');
  }

  private setMockInterval(value: number): void {
    this.mockIntervalSec = Math.max(1, Math.min(60, Math.round(value)));
  }

  // ---------- 后台长时任务 ----------

  private async toggleBackground(isOn: boolean): Promise<void> {
    this.bgEnabled = isOn;
    const ctx: common.UIAbilityContext = this.hostContext();
    if (isOn) {
      await this.ensureLocationPermission();
      try {
        await this.runner.start(ctx, ctx.abilityInfo.bundleName, 'EntryAbility');
        this.bgActive = true;
        this.toast('后台运行已开启');
      } catch (err) {
        this.bgEnabled = false;
        this.bgActive = false;
        this.toast('后台任务启动失败，请确认系统允许后台运行');
      }
    } else {
      try {
        await this.runner.stop(ctx);
      } catch (err) {
        this.bgActive = false;
      }
      this.bgActive = false;
      this.toast('后台运行已关闭');
    }
  }

  // ---------- 定位与工具 ----------

  private async fetchSysLocation(): Promise<void> {
    const granted: boolean = await this.ensureLocationPermission();
    if (!granted) {
      this.sysLocInfo = '无定位权限';
      return;
    }
    try {
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeoutMs: 8000
      });
      const mockFlag: string = (loc.isFromMock !== undefined && loc.isFromMock) ? '是 (MOCK)' : '否 (真实)';
      const spd: number = loc.speed !== undefined ? loc.speed : 0;
      this.sysLocInfo = 'lat=' + loc.latitude.toFixed(6) +
        ' lng=' + loc.longitude.toFixed(6) +
        ' 精度=' + (loc.accuracy !== undefined ? loc.accuracy.toFixed(1) : '?') + 'm' +
        ' 速度=' + spd.toFixed(2) + 'm/s' +
        ' isFromMock=' + mockFlag;
    } catch (err) {
      this.sysLocInfo = '读取失败: ' + (err as Error).message;
    }
  }

  private async locateMe(): Promise<void> {
    const granted: boolean = await this.ensureLocationPermission();
    if (!granted) {
      this.toast('未获得定位权限，可继续手动选点');
      return;
    }

    try {
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
        timeoutMs: 8000
      });
      this.runJs('window.mapApi.center(' + loc.latitude + ',' + loc.longitude + ',15)');
      this.curLat = loc.latitude;
      this.curLng = loc.longitude;
      this.toast('已居中到当前位置');
    } catch (err) {
      this.toast('获取当前位置失败，请检查定位开关');
    }
  }

  private async ensureLocationPermission(): Promise<boolean> {
    const ctx: common.UIAbilityContext = this.hostContext();
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const perms: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
      const result = await atManager.requestPermissionsFromUser(ctx, perms);
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] === 0) {
          return true;
        }
      }
      return false;
    } catch (err) {
      return false;
    }
  }

  private applyInputCoord(): void {
    if (this.lonText.length === 0 || this.latText.length === 0) {
      this.toast('请输入经度和纬度');
      return;
    }
    const lat: number = Number(this.latText);
    const lng: number = Number(this.lonText);
    if (!this.isValidLatLng(lat, lng) || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      this.toast('坐标格式不正确');
      return;
    }
    this.addPoint(lat, lng, true);
  }

  private jumpToCity(city: CityPreset): void {
    this.addPoint(city.latitude, city.longitude, false);
    this.runJs('window.mapApi.center(' + city.latitude + ',' + city.longitude + ',13)');
    this.toast('已添加 ' + city.name + '（' + city.province + '）');
  }

  private onCityQueryChange(value: string): void {
    this.cityQuery = value;
    this.cityResults = searchCities(value, 9);
  }

  private clearCityQuery(): void {
    this.cityQuery = '';
    this.cityResults = popularCities();
  }

  private runJs(script: string): void {
    if (!this.mapReady) {
      return;
    }
    this.controller.runJavaScript(script).catch(() => {
      // WebView 尚未完成加载时忽略
    });
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      // 提示失败不影响主流程
    }
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private statusText(): string {
    let base: string = '待机';
    if (this.simState === SimState.RUNNING) {
      base = '运行中';
    } else if (this.simState === SimState.PAUSED) {
      base = '已暂停';
    } else if (this.simState === SimState.FINISHED) {
      base = '已完成';
    }
    if (this.bgActive) {
      return base + ' · 后台';
    }
    return base;
  }

  private statusColor(): string {
    if (this.simState === SimState.RUNNING) {
      return C_GREEN;
    }
    if (this.simState === SimState.PAUSED) {
      return C_AMBER;
    }
    if (this.simState === SimState.FINISHED) {
      return C_ACCENT;
    }
    return C_SUB;
  }

  private statusBg(): string {
    if (this.simState === SimState.RUNNING) {
      return 'rgba(34,197,94,0.14)';
    }
    if (this.simState === SimState.PAUSED) {
      return 'rgba(245,158,11,0.14)';
    }
    if (this.simState === SimState.FINISHED) {
      return 'rgba(56,189,248,0.14)';
    }
    return 'rgba(130,152,174,0.12)';
  }

  // ---------- 生命周期 ----------

  onPageShow(): void {
    this.pageVisible = true;
    this.syncStats();
    this.refreshSaved();
  }

  onPageHide(): void {
    this.pageVisible = false;
    if (!this.bgEnabled && this.simState === SimState.RUNNING) {
      this.engine.pause();
      this.stopTimer();
      this.syncStats();
    }
  }

  aboutToDisappear(): void {
    this.stopTimer();
    this.broadcaster.stop().catch(() => {
      // 忽略
    });
    const ctx: common.UIAbilityContext = this.hostContext();
    this.runner.stop(ctx).catch(() => {
      // 页面销毁时忽略
    });
  }

  // ---------- UI ----------

  @Builder
  statusChip() {
    Row({ space: 6 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.statusColor())
        .borderRadius(4)
      Text(this.statusText())
        .fontSize(11)
        .fontColor(this.statusColor())
        .fontWeight(FontWeight.Medium)
    }
    .padding({ left: 10, right: 12, top: 6, bottom: 6 })
    .backgroundColor(this.statusBg())
    .borderRadius(20)
    .border({ width: 1, color: this.statusColor() })
  }

  @Builder
  statCell(label: string, value: string, color: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(10).fontColor(C_SUB)
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  sectionLabel(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(C_SUB)
      .fontWeight(FontWeight.Medium)
  }

  build() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('定位模拟器')
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor(C_TEXT)
          Text('地图选点 · 轨迹模拟 · 后台运行')
            .fontSize(11)
            .fontColor(C_SUB)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.statusChip()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 12 })

      Scroll() {
        Column({ space: 12 }) {
          // 地图
          Column() {
            Web({ src: $rawfile('map.html'), controller: this.controller })
              .javaScriptAccess(true)
              .domStorageAccess(true)
              .zoomAccess(false)
              .javaScriptProxy({
                object: this.bridge,
                name: 'bridge',
                methodList: ['onPick', 'onRect'],
                controller: this.controller
              })
              .onPageEnd(() => {
                this.mapReady = true;
                this.pushPoints();
                this.runJs("window.mapApi.setMode('" + this.mapMode + "')");
              })
              .width('100%')
              .height(300)

            Row({ space: 8 }) {
              Text('选点')
                .fontSize(12)
                .fontColor(this.mapMode === 'pick' ? '#04121C' : C_SUB)
                .backgroundColor(this.mapMode === 'pick' ? C_ACCENT : C_SUNKEN)
                .borderRadius(8)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => this.setMapMode('pick'))
              Text('框选')
                .fontSize(12)
                .fontColor(this.mapMode === 'rect' ? '#04121C' : C_SUB)
                .backgroundColor(this.mapMode === 'rect' ? C_ACCENT : C_SUNKEN)
                .borderRadius(8)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .onClick(() => this.setMapMode('rect'))
              Blank()
              Text('清除')
                .fontSize(12)
                .fontColor(C_SUB)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .onClick(() => this.clearPoints())
              Text('定位')
                .fontSize(12)
                .fontColor(C_ACCENT)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .onClick(() => this.locateMe())
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(C_SUNKEN)
          }
          .width('100%')
          .borderRadius(16)
          .clip(true)
          .border({ width: 1, color: C_LINE })

          // 框选结果
          if (this.hasRect) {
            Column({ space: 10 }) {
              Row() {
                this.sectionLabel('已框选区域')
                Blank()
                Text('清除框选')
                  .fontSize(11)
                  .fontColor(C_SUB)
                  .onClick(() => this.clearRect())
              }
              .width('100%')

              Text(this.rectInfo)
                .fontSize(13)
                .fontColor(C_TEXT)
                .width('100%')

              Row({ space: 10 }) {
                Button('取中心点')
                  .fontSize(12)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor(C_ACCENT)
                  .fontColor('#04121C')
                  .onClick(() => this.takeRectCenter())
                Button('框内路径')
                  .fontSize(12)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor(C_ACCENT)
                  .fontColor('#04121C')
                  .onClick(() => this.takeRectPath())
                Button('随机点')
                  .fontSize(12)
                  .height(34)
                  .layoutWeight(1)
                  .backgroundColor('#182636')
                  .fontColor(C_TEXT)
                  .onClick(() => this.takeRectRandom())
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor(C_CARD)
            .borderRadius(14)
            .border({ width: 1, color: 'rgba(56,189,248,0.35)' })
          }

          // 点位
          Column({ space: 10 }) {
            Row() {
              this.sectionLabel('点位')
              Text('  ' + this.points.length.toString() + ' 个')
                .fontSize(11)
                .fontColor(C_ACCENT)
              Blank()
              if (this.points.length > 0) {
                Text('清空')
                  .fontSize(11)
                  .fontColor(C_SUB)
                  .onClick(() => this.clearPoints())
              }
            }
            .width('100%')

            if (this.points.length === 0) {
              Text('点击地图添加点，或使用下方城市搜索与坐标输入')
                .fontSize(12)
                .fontColor(C_SUB)
                .width('100%')
                .padding({ top: 4, bottom: 4 })
            } else {
              Scroll() {
                Row({ space: 8 }) {
                  ForEach(this.points, (item: LatLng, index: number) => {
                    Row({ space: 8 }) {
                      Text('P' + (index + 1).toString())
                        .fontSize(11)
                        .fontColor(C_ACCENT)
                      Text(formatLatLng(item.latitude, item.longitude))
                        .fontSize(11)
                        .fontColor(C_TEXT)
                      Text('×')
                        .fontSize(13)
                        .fontColor(C_SUB)
                        .onClick(() => this.removePoint(index))
                    }
                    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                    .backgroundColor(C_SUNKEN)
                    .borderRadius(8)
                    .border({ width: 1, color: C_LINE })
                  }, (item: LatLng, index: number) => index.toString() + '_' + item.latitude.toString())
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }

            Row() {
              Text(this.cityQuery.trim().length === 0 ? '热门城市' : '搜索结果')
                .fontSize(12)
                .fontColor(C_SUB)
                .fontWeight(FontWeight.Medium)
              Blank()
              if (this.cityQuery.trim().length > 0) {
                Text('清除')
                  .fontSize(11)
                  .fontColor(C_SUB)
                  .onClick(() => this.clearCityQuery())
              }
            }
            .width('100%')

            TextInput({ text: this.cityQuery, placeholder: '搜索城市：名称 / 拼音 / 省份' })
              .height(38)
              .width('100%')
              .fontSize(12)
              .fontColor(C_TEXT)
              .placeholderColor(C_SUB)
              .caretColor(C_ACCENT)
              .backgroundColor(C_SUNKEN)
              .borderRadius(8)
              .onChange((value: string) => this.onCityQueryChange(value))

            if (this.cityResults.length === 0) {
              Text('未找到匹配城市，可继续使用地图选点或坐标输入')
                .fontSize(11)
                .fontColor(C_SUB)
                .width('100%')
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.cityResults, (city: CityPreset) => {
                  Row({ space: 6 }) {
                    Text(city.name)
                      .fontSize(12)
                      .fontColor(C_TEXT)
                    Text(city.province)
                      .fontSize(10)
                      .fontColor(C_SUB)
                  }
                  .padding({ left: 11, right: 11, top: 7, bottom: 7 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor(C_SUNKEN)
                  .borderRadius(8)
                  .border({ width: 1, color: C_LINE })
                  .onClick(() => this.jumpToCity(city))
                }, (city: CityPreset) => city.name)
              }
              .width('100%')
            }

            Row({ space: 8 }) {
              TextInput({ text: this.lonText, placeholder: '经度' })
                .type(InputType.NUMBER_DECIMAL)
                .onChange((value: string) => {
                  this.lonText = value;
                })
                .height(38)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(C_TEXT)
                .placeholderColor(C_SUB)
                .caretColor(C_ACCENT)
                .backgroundColor(C_SUNKEN)
                .borderRadius(8)
              TextInput({ text: this.latText, placeholder: '纬度' })
                .type(InputType.NUMBER_DECIMAL)
                .onChange((value: string) => {
                  this.latText = value;
                })
                .height(38)
                .layoutWeight(1)
                .fontSize(12)
                .fontColor(C_TEXT)
                .placeholderColor(C_SUB)
                .caretColor(C_ACCENT)
                .backgroundColor(C_SUNKEN)
                .borderRadius(8)
              Button('前往')
                .fontSize(12)
                .height(38)
                .width(62)
                .backgroundColor('#182636')
                .fontColor(C_ACCENT)
                .onClick(() => this.applyInputCoord())
            }
            .width('100%')

            Divider().color(C_LINE)

            Row() {
              this.sectionLabel('路线存档')
              Blank()
              if (this.points.length > 0) {
                Text('保存当前 ' + this.points.length.toString() + ' 点')
                  .fontSize(11)
                  .fontColor(C_ACCENT)
                  .onClick(() => this.saveCurrentRoute())
              }
            }
            .width('100%')

            if (this.savedRoutes.length === 0) {
              Text('暂无存档；选好点位后点右上“保存当前”，重启应用也能恢复')
                .fontSize(11)
                .fontColor(C_SUB)
                .width('100%')
            } else {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.savedRoutes, (meta: RouteMeta) => {
                  Row({ space: 6 }) {
                    Text(meta.name)
                      .fontSize(12)
                      .fontColor(C_TEXT)
                    Text(meta.count.toString() + '点')
                      .fontSize(10)
                      .fontColor(C_ACCENT)
                    Text('×')
                      .fontSize(13)
                      .fontColor(C_SUB)
                      .onClick(() => this.deleteRouteByName(meta))
                  }
                  .padding({ left: 11, right: 11, top: 7, bottom: 7 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor(C_SUNKEN)
                  .borderRadius(8)
                  .border({ width: 1, color: C_LINE })
                  .onClick(() => this.loadRoute(meta))
                }, (meta: RouteMeta) => meta.name)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_CARD)
          .borderRadius(14)
          .border({ width: 1, color: C_LINE })

          // 模拟参数
          Column({ space: 14 }) {
            Row() {
              this.sectionLabel('模拟模式')
              Blank()
              Row() {
                Text('定点')
                  .fontSize(12)
                  .fontColor(this.mode === SimMode.FIXED ? '#04121C' : C_SUB)
                  .backgroundColor(this.mode === SimMode.FIXED ? C_ACCENT : C_SUNKEN)
                  .borderRadius(7)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .onClick(() => this.setMode(SimMode.FIXED))
                Text('轨迹')
                  .fontSize(12)
                  .fontColor(this.mode === SimMode.ROUTE ? '#04121C' : C_SUB)
                  .backgroundColor(this.mode === SimMode.ROUTE ? C_ACCENT : C_SUNKEN)
                  .borderRadius(7)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .margin({ left: 6 })
                  .onClick(() => this.setMode(SimMode.ROUTE))
              }
            }
            .width('100%')

            Row() {
              Column({ space: 3 }) {
                Text('循环轨迹')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Text('到达终点后自动回到起点继续')
                  .fontSize(10)
                  .fontColor(C_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.loop })
                .selectedColor(C_ACCENT)
                .onChange((isOn: boolean) => this.toggleLoop(isOn))
            }
            .width('100%')

            Column({ space: 6 }) {
              Row() {
                Text('模拟速度')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Blank()
                Text(formatSpeedMs(this.speedMs))
                  .fontSize(13)
                  .fontColor(C_ACCENT)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')

              Slider({ value: this.speedMs, min: 0, max: 50, step: 0.1 })
                .selectedColor(C_ACCENT)
                .trackColor('#1B2A3A')
                .onChange((value: number) => this.setSpeedMs(value))

              Row({ space: 8 }) {
                Text('步行 1.4')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .onClick(() => this.setSpeedMs(1.4))
                Text('骑行 4.2')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .onClick(() => this.setSpeedMs(4.2))
                Text('驾车 16.7')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .onClick(() => this.setSpeedMs(16.7))
                Text('高铁 55.6')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .onClick(() => this.setSpeedMs(55.6))
              }
              .width('100%')
            }
            .width('100%')

            Column({ space: 6 }) {
              Row() {
                Text('速度浮动')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Blank()
                Text('±' + this.speedJitterPct.toFixed(0) + '%')
                  .fontSize(13)
                  .fontColor(C_AMBER)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')

              Slider({ value: this.speedJitterPct, min: 0, max: 50, step: 1 })
                .selectedColor(C_AMBER)
                .trackColor('#1B2A3A')
                .onChange((value: number) => this.setJitter(value))

              Text('运行中瞬时速度在此范围内随机波动；0 为恒定速度')
                .fontSize(10)
                .fontColor(C_SUB)
            }
            .width('100%')

            Divider().color(C_LINE)

            Row() {
              Column({ space: 3 }) {
                Text('坐标广播')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Text(this.broadcastRunning
                  ? 'UDP 广播中：' + this.broadcastPort.toString()
                  : '以 JSON 向局域网 UDP 广播模拟坐标')
                  .fontSize(10)
                  .fontColor(this.broadcastRunning ? C_GREEN : C_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.broadcastEnabled })
                .selectedColor(C_GREEN)
                .onChange((isOn: boolean) => {
                  this.toggleBroadcast(isOn);
                })
            }
            .width('100%')

            if (this.broadcastEnabled) {
              Row({ space: 8 }) {
                Text('端口')
                  .fontSize(12)
                  .fontColor(C_SUB)
                TextInput({ text: this.broadcastPort.toString(), placeholder: '39527' })
                  .type(InputType.Number)
                  .onChange((value: string) => this.onPortChange(value))
                  .height(34)
                  .layoutWeight(1)
                  .fontSize(12)
                  .fontColor(C_TEXT)
                  .placeholderColor(C_SUB)
                  .caretColor(C_ACCENT)
                  .backgroundColor(C_SUNKEN)
                  .borderRadius(7)
                Text('目标 255.255.255.255')
                  .fontSize(10)
                  .fontColor(C_SUB)
              }
              .width('100%')
            }

            Divider().color(C_LINE)

            Column({ space: 10 }) {
              Row() {
                Column({ space: 3 }) {
                  Text('系统 GPS 模拟')
                    .fontSize(13)
                    .fontColor(C_TEXT)
                  Text('HarmonyOS 7.0+ testhelper 覆盖整机定位')
                    .fontSize(10)
                    .fontColor(this.systemMockActive ? C_GREEN : C_SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                if (!this.systemMockActive) {
                  Button('启用模拟')
                    .fontSize(12)
                    .height(34)
                    .backgroundColor(C_ACCENT)
                    .fontColor('#04121C')
                    .onClick(() => this.enableSystemMock())
                } else {
                  Button('停止模拟')
                    .fontSize(12)
                    .height(34)
                    .backgroundColor(C_AMBER)
                    .fontColor('#04121C')
                    .onClick(() => this.disableSystemMock())
                }
              }
              .width('100%')

              Row({ space: 8 }) {
                Text('更新间隔')
                  .fontSize(11)
                  .fontColor(C_SUB)
                TextInput({ text: this.mockIntervalSec.toString(), placeholder: '1' })
                  .type(InputType.Number)
                  .onChange((value: string) => {
                    const n: number = Number(value);
                    if (Number.isFinite(n)) {
                      this.setMockInterval(n);
                    }
                  })
                  .height(30)
                  .width(48)
                  .fontSize(11)
                  .fontColor(C_TEXT)
                  .backgroundColor(C_SUNKEN)
                  .borderRadius(6)
                Text('秒 (testhelper set-mocked-locations)')
                  .fontSize(10)
                  .fontColor(C_SUB)
                Blank()
              }
              .width('100%')

              if (this.systemMockActive) {
                Text(this.mockGpxInfo)
                  .fontSize(10)
                  .fontColor(C_ACCENT)
                  .width('100%')
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .backgroundColor('rgba(56,189,248,0.10)')
                  .borderRadius(6)
              } else {
                Text('需要 PC 端桥接脚本监听 UDP 端口，将 GPX 推送到 /data/local/tmp 并调用 testhelper enable-location-mock')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .width('100%')
              }
            }
            .width('100%')

            Divider().color(C_LINE)

            Column({ space: 8 }) {
              Row() {
                Text('系统定位诊断')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Blank()
                Button('读取系统定位')
                  .fontSize(11)
                  .height(30)
                  .backgroundColor(C_ACCENT)
                  .fontColor('#04121C')
                  .onClick(() => this.fetchSysLocation())
              }
              .width('100%')

              if (this.sysLocInfo.length > 0) {
                Text(this.sysLocInfo)
                  .fontSize(10)
                  .fontColor(C_TEXT)
                  .width('100%')
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .backgroundColor(C_SUNKEN)
                  .borderRadius(6)
              } else {
                Text('点击按钮读取 geoLocationManager 当前定位，含 isFromMock 字段，用于验证 testhelper 是否生效')
                  .fontSize(10)
                  .fontColor(C_SUB)
                  .width('100%')
              }
            }
            .width('100%')

            Divider().color(C_LINE)

            Row() {
              Column({ space: 3 }) {
                Text('后台运行')
                  .fontSize(13)
                  .fontColor(C_TEXT)
                Text(this.bgActive ? '长时任务已激活，切到后台继续推进' : '切换到后台后保持模拟运行')
                  .fontSize(10)
                  .fontColor(this.bgActive ? C_GREEN : C_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.bgEnabled })
                .selectedColor(C_GREEN)
                .onChange((isOn: boolean) => {
                  this.toggleBackground(isOn);
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_CARD)
          .borderRadius(14)
          .border({ width: 1, color: C_LINE })

          // 操作
          Row({ space: 10 }) {
            Button(this.primaryLabel(), { type: ButtonType.Normal })
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .height(46)
              .layoutWeight(1)
              .borderRadius(12)
              .backgroundColor(this.simState === SimState.RUNNING ? C_AMBER : C_ACCENT)
              .fontColor('#04121C')
              .onClick(() => this.onPrimaryAction())
            Button('停止', { type: ButtonType.Normal })
              .fontSize(14)
              .height(46)
              .width(92)
              .borderRadius(12)
              .backgroundColor('#182636')
              .fontColor(this.simState === SimState.IDLE ? C_SUB : C_TEXT)
              .onClick(() => this.stopSimulation())
          }
          .width('100%')

          // 实时数据
          Column({ space: 12 }) {
            Row() {
              this.sectionLabel('实时数据')
              Blank()
              Text(this.mode === SimMode.ROUTE
                ? '轨迹进度 ' + this.progressVal.toString() + '%'
                : '定点模拟')
                .fontSize(11)
                .fontColor(C_ACCENT)
            }
            .width('100%')

            Progress({ value: this.progressVal, total: 100, type: ProgressType.Linear })
              .color(C_ACCENT)
              .backgroundColor('#16202B')
              .width('100%')
              .height(4)

            Row() {
              this.statCell('当前坐标', formatLatLng(this.curLat, this.curLng), C_ACCENT)
              this.statCell('速度', formatSpeedMs(this.curSpeedMs), C_GREEN)
            }
            .width('100%')

            Row() {
              this.statCell('已走距离', formatDistance(this.distanceM), C_TEXT)
              this.statCell('用时', formatDuration(this.elapsedMs), C_TEXT)
            }
            .width('100%')

            Row() {
              this.statCell('方位角', this.curBearing.toFixed(0) + '° ' + compassLabel(this.curBearing), C_SUB)
              this.statCell('轨迹总长', formatDistance(this.engine.getTotalDistance()), C_SUB)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(C_CARD)
          .borderRadius(14)
          .border({ width: 1, color: C_LINE })

          Text('HarmonyOS 7.0+ 内置 testhelper 位置模拟能力，可覆盖整机 GPS（其他应用可见）。本应用生成 GPX 轨迹 → 通过 UDP 广播给 PC 端桥接脚本 → 脚本调 hdc + testhelper enable/set-mocked-locations 即可实时改写手机定位。设备需开启开发者选项。速度单位 m/s，支持速度浮动。')
            .fontSize(10)
            .fontColor('#5F7488')
            .lineHeight(16)
            .width('100%')
            .padding({ left: 4, right: 4, top: 2, bottom: 8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C_BG)
  }
}
