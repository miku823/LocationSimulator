#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LocationSimulator PC 桥接脚本 —— HarmonyOS 7.0+ 系统级 GPS 模拟

工作原理：
  1. 监听 UDP 广播 (默认 39527 端口)
  2. 收到 gpxReady 消息后：
     a. 通过 hdc file recv 从应用沙箱拉取 GPX 文件
     b. 通过 hdc file send 推到设备 /data/local/tmp/track.gpx
     c. 执行 hdc shell testhelper enable-location-mock
     d. 执行 hdc shell testhelper set-mocked-locations /data/local/tmp/track.gpx [interval]
  3. 收到 gpxDone 消息后：
     a. 执行 hdc shell testhelper disable-location-mock 恢复真实 GPS
  4. 同时接收 tick 消息（可选：用于实时显示模拟状态）

前置条件：
  - 设备已通过 USB 或无线 (hdc tconn <ip>:5555) 连接
  - 设备已开启开发者选项
  - 电脑已安装 hdc (HarmonyOS SDK)
  - 应用已安装并开启了坐标广播

用法：
  python bridge.py [--port 39527] [--hdc "path/to/hdc.exe"] [--device <serial>]
"""

import argparse
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path


DEFAULT_PORT = 39527
GPX_TARGET = "/data/local/tmp/track.gpx"
BUNDLE = "com.demo.locationsimulator"


def find_hdc_explicit():
    """Try to find hdc.exe from env or common paths."""
    env_hdc = os.environ.get("HDC_PATH") or os.environ.get("HDC_EXE")
    if env_hdc and Path(env_hdc).exists():
        return env_hdc

    candidates = [
        r"E:\OpenHarmonyStudio\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe",
        r"C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe",
        "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc",
        os.path.expanduser("~/Library/Huawei/Sdk/default/openharmony/toolchains/hdc"),
    ]
    for c in candidates:
        if Path(c).exists():
            return c

    # Fallback: just "hdc" and let PATH resolve
    return "hdc"


class Bridge:
    def __init__(self, port, hdc_exe, device=None):
        self.port = port
        self.hdc = hdc_exe
        self.device = device
        self.sock = None
        self.mock_active = False
        self.last_gpx_path = None
        self.last_interval = 1
        self.last_point_count = 0

    def _hdc(self, *args, timeout=30):
        base = [self.hdc]
        if self.device:
            base += ["-t", self.device]
        base += list(args)
        print(f"  [hdc] {' '.join(base)}")
        try:
            result = subprocess.run(base, capture_output=True, text=True, timeout=timeout)
            out = (result.stdout or "") + (result.stderr or "")
            if out.strip():
                print(f"  -> {out.strip()}")
            return result.returncode == 0, out
        except subprocess.TimeoutExpired:
            print(f"  [hdc] TIMEOUT after {timeout}s")
            return False, ""
        except FileNotFoundError:
            print(f"  [hdc] NOT FOUND: {self.hdc}")
            return False, ""

    def enable_mock(self):
        print("\n==> enable-location-mock")
        ok, _ = self._hdc("shell", "testhelper", "enable-location-mock")
        if ok:
            self.mock_active = True
            print("    ✓ 系统级 GPS 模拟已启用")
        else:
            print("    ✗ 启用失败（设备需开启开发者选项 + HarmonyOS 7.0+）")
        return ok

    def disable_mock(self):
        print("\n==> disable-location-mock")
        ok, _ = self._hdc("shell", "testhelper", "disable-location-mock")
        if ok:
            self.mock_active = False
            print("    ✓ 已恢复真实 GPS")
        else:
            print("    ✗ 禁用失败")
        return ok

    def push_gpx_and_mock(self, sandbox_path, interval_sec):
        print(f"\n==> GPX 推送 + 模拟启动")
        print(f"    应用沙箱: {sandbox_path}")
        print(f"    推送目标: {GPX_TARGET}")
        print(f"    间隔: {interval_sec}s")

        # 1. 启用位置模拟
        self.enable_mock()

        # 2. 从应用沙箱 recv GPX 到本地临时目录
        local_gpx = Path.cwd() / "_bridge_track.gpx"
        ok, out = self._hdc("file", "recv", sandbox_path, str(local_gpx))
        if not ok:
            print(f"    ✗ file recv 失败: {out.strip()}")
            return False

        # 3. 推到 /data/local/tmp/
        ok, out = self._hdc("file", "send", str(local_gpx), GPX_TARGET)
        if not ok:
            print(f"    ✗ file send 失败: {out.strip()}")
            return False

        # 4. set-mocked-locations
        ok, out = self._hdc("shell", "testhelper", "set-mocked-locations",
                            GPX_TARGET, str(interval_sec))
        if ok:
            print(f"    ✓ testhelper set-mocked-locations 成功")
        else:
            print(f"    ✗ set-mocked-locations 失败")
            # 常见原因：GPX 超过 1000 点 / 路径不对 / 格式错误

        # 清理本地临时文件
        try:
            local_gpx.unlink(missing_ok=True)
        except Exception:
            pass

        return ok

    def start(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("0.0.0.0", self.port))
        self.sock.settimeout(1.0)

        print(f"\n⟳ 桥接已就绪，监听 UDP 0.0.0.0:{self.port}")
        print(f"  hdc = {self.hdc}")
        if self.device:
            print(f"  设备 = {self.device}")
        print("  Ctrl+C 退出\n")

        last_tick_print = 0

        while True:
            try:
                data, addr = self.sock.recvfrom(65536)
            except socket.timeout:
                continue
            except KeyboardInterrupt:
                break
            except OSError:
                break

            try:
                msg = json.loads(data.decode("utf-8"))
            except Exception:
                continue

            mtype = msg.get("type", "unknown")

            if mtype == "tick":
                now = time.time()
                if now - last_tick_print > 2.0:  # 限流，每 2s 打印一次
                    lat = msg.get("lat", 0)
                    lng = msg.get("lng", 0)
                    spd = msg.get("speedMs", 0)
                    print(f"    [tick] {lat:.6f},{lng:.6f}  {spd:.1f} m/s", end="\r")
                    last_tick_print = now

            elif mtype == "gpxReady":
                path = msg.get("gpxPath", "")
                count = msg.get("pointCount", 0)
                interval = msg.get("intervalSec", 1)
                speed = msg.get("speedMs", 4.2)
                self.last_gpx_path = path
                self.last_interval = interval
                self.last_point_count = count
                print(f"\n\n📡 收到 GPX 就绪: {count} 点, 间隔 {interval}s, 速度 {speed} m/s")
                print(f"   沙箱路径: {path}")
                self.push_gpx_and_mock(path, interval)

            elif mtype == "gpxDone":
                print(f"\n\n📡 收到停止模拟请求")
                self.disable_mock()

            else:
                pass

    def cleanup(self):
        print("\n\n⟳ 退出清理...")
        if self.mock_active:
            self.disable_mock()
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
        print("  已退出。")


def main():
    parser = argparse.ArgumentParser(
        description="LocationSimulator PC 桥接 —— HarmonyOS 7.0 testhelper GPS 模拟"
    )
    parser.add_argument("--port", type=int, default=DEFAULT_PORT,
                        help=f"UDP 监听端口 (默认 {DEFAULT_PORT})")
    parser.add_argument("--hdc", type=str, default=None,
                        help="hdc 可执行文件路径")
    parser.add_argument("--device", type=str, default=None,
                        help="指定设备 serial (多设备场景)")
    args = parser.parse_args()

    hdc_exe = args.hdc or find_hdc_explicit()
    print(f"hdc = {hdc_exe}")

    bridge = Bridge(args.port, hdc_exe, args.device)

    try:
        # 先检查设备是否在线
        if args.device:
            ok, out = bridge._hdc("shell", "echo", "bridge-check")
            if not ok:
                print(f"⚠ 设备 {args.device} 可能离线: {out.strip()}")
        else:
            ok, out = bridge._hdc("list", "targets")
            targets = [l for l in out.splitlines() if l.strip() and not l.strip().startswith("[")]
            if not targets:
                print("⚠ 当前没有连接的设备。请先 hdc tconn <ip>:5555 或 USB 连接。")

        bridge.start()
    except KeyboardInterrupt:
        pass
    finally:
        bridge.cleanup()


if __name__ == "__main__":
    main()
