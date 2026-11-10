import { socket } from '@kit.NetworkKit';

/**
 * 通过 UDP 广播与 PC 端桥接脚本通信。
 * 消息类型:
 *   tick     — 每 500ms 推送一次模拟坐标 (lat/lng/speedMs/bearing/time)
 *   gpxReady — 当用户触发"系统模拟"时，把 GPX 元信息广播出去 (path, count, intervalSec, speedMs, mode)
 *   gpxDone  — 停止模拟，通知 PC 端调用 testhelper disable-location-mock
 */
export class LocationBroadcaster {
  private udp: socket.UDPSocket | null = null;
  private port: number = 39527;
  private targetIp: string = '255.255.255.255';
  private started: boolean = false;

  isRunning(): boolean {
    return this.started;
  }

  getPort(): number {
    return this.port;
  }

  async start(port: number): Promise<void> {
    if (this.started) {
      return;
    }
    this.port = port;
    const sock: socket.UDPSocket = socket.constructUDPSocketInstance();
    this.udp = sock;
    try {
      await sock.bind({ address: '0.0.0.0', port: 0, family: 1 });
      await sock.setExtraOptions({ broadcast: true });
      this.started = true;
    } catch (err) {
      this.udp = null;
      throw new Error('broadcast start failed');
    }
  }

  async stop(): Promise<void> {
    if (!this.started || this.udp === null) {
      return;
    }
    this.started = false;
    try {
      await this.udp.close();
    } catch (err) {
      // 忽略关闭异常
    }
    this.udp = null;
  }

  private async send(payload: string): Promise<void> {
    if (!this.started || this.udp === null) {
      return;
    }
    try {
      await this.udp.send({
        data: payload,
        address: { address: this.targetIp, port: this.port, family: 1 }
      });
    } catch (err) {
      // 发送失败不影响主流程
    }
  }

  /** 推送一条模拟定位 tick */
  async tick(lat: number, lng: number, speedMs: number, bearing: number): Promise<void> {
    await this.send(JSON.stringify({
      type: 'tick',
      lat: lat,
      lng: lng,
      speedMs: Number(speedMs.toFixed(3)),
      bearing: Number(bearing.toFixed(2)),
      time: Date.now()
    }));
  }

  /** GPX 导出完成，请求 PC 端推到 /data/local/tmp 并启用 testhelper */
  async gpxReady(
    gpxPath: string,
    pointCount: number,
    intervalSec: number,
    speedMs: number,
    mode: string
  ): Promise<void> {
    await this.send(JSON.stringify({
      type: 'gpxReady',
      gpxPath: gpxPath,
      pointCount: pointCount,
      intervalSec: intervalSec,
      speedMs: speedMs,
      mode: mode,
      time: Date.now()
    }));
  }

  /** 通知 PC 端停止模拟（调用 testhelper disable-location-mock） */
  async gpxDone(): Promise<void> {
    await this.send(JSON.stringify({
      type: 'gpxDone',
      time: Date.now()
    }));
  }
}
