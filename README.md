# LocationSimulator · 鸿蒙定位模拟器

基于 HarmonyOS（ArkTS / ArkUI）的位置模拟调试工具：在地图上选点或绘制轨迹，按设定速度播放，并可通过 HarmonyOS 7.0+ 的 `testhelper` 将模拟坐标注入系统位置服务。

> 仅用于开发与测试。请勿用于考勤作弊、游戏外挂等违反法律法规或平台协议的场景。

## 功能特性

- **瓦片地图交互**：内置 WebView 高德瓦片地图（GCJ-02 显示、内部 WGS-84 坐标），支持缩放、点选、框选、城市搜索定位。
- **两种模拟模式**
  - 定点模式：锁定单一坐标。
  - 轨迹模式：沿路径点顺序移动，可选「循环轨迹」到达终点后回到起点。
- **速度以 m/s 显示**：滑块范围 0–50 m/s，内置步行 1.4 / 骑行 4.2 / 驾车 16.7 / 高铁 55.6 快捷档位。
- **速度浮动**：可设 ±0%–50% 随机抖动，模拟真实行驶的速度波动。
- **实时数据面板**：当前经纬度、瞬时速度、方位角、已行进距离、进度。
- **轨迹持久化**：路径保存 / 读取（Preferences），支持「框内路径」自动生成蛇形路线。
- **系统 GPS 模拟**：将轨迹导出为标准 GPX 1.1（含 `speed` / `direction`），配合 PC 端桥接脚本调用 `testhelper` 覆盖整机定位（受下文限制说明约束）。
- **UDP 坐标广播**：以 JSON 形式广播模拟坐标，便于外部工具消费。
- **后台长时任务**：`backgroundModes: ["location"]`，切后台后继续模拟。

## 目录结构

```
LocationSimulator/
├── AppScope/                       # 应用级配置与资源
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/       # EntryAbility（入口）
│       │   ├── model/
│       │   │   ├── SimulatorEngine.ets   # 模拟引擎（定点/轨迹/速度浮动）
│       │   │   ├── GeoUtils.ets          # 距离、方位角、坐标转换、格式化
│       │   │   ├── GpxBuilder.ets        # 轨迹采样 + GPX 1.1 生成
│       │   │   ├── RouteStore.ets        # 路径持久化
│       │   │   └── Cities.ets            # 城市坐标表
│       │   ├── pages/
│       │   │   └── Index.ets             # 主界面与全部交互逻辑
│       │   └── service/
│       │       ├── BackgroundRunner.ets  # 后台长时任务
│       │       ├── LocationBroadcaster.ets # UDP 广播
│       │       └── GpxExporter.ets       # GPX 落盘
│       ├── resources/rawfile/map.html    # 瓦片地图与 JS 桥
│       └── module.json5                  # 权限与 Ability 配置
├── pc_bridge.py                    # PC 端桥接脚本（UDP → hdc → testhelper）
├── build-profile.json5
└── oh-package.json5
```

## 环境要求

| 项目 | 要求 |
|---|---|
| IDE | DevEco Studio（HarmonyOS SDK） |
| SDK | targetSdkVersion 26.0.0，compatibleSdkVersion 5.0.0(12) |
| 设备 | HarmonyOS 7.0（API 26）及以上，手机 |
| 系统模拟 | 设备需开启「开发者选项」 |

## 构建与安装

```powershell
# 环境变量（按本机安装路径调整）
$env:DEVECO_SDK_HOME="E:\OpenHarmonyStudio\DevEco Studio\sdk"
$env:NODE_HOME="E:\OpenHarmonyStudio\DevEco Studio\tools\node"
$env:PATH="$env:NODE_HOME;$env:PATH"

# 编译（系统级位置模拟需 debug 签名，见限制说明）
hvigorw.bat --mode module -p module=entry@default -p product=default `
  assembleHap -p buildMode=debug --no-daemon

# 安装并启动
hdc install -r entry\build\default\outputs\default\entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.demo.locationsimulator
```

> 首次编译需在 DevEco Studio 中配置签名（`File → Project Structure → Signing Configs`）。

## 使用说明

1. **选点 / 框选**：在地图上单击添加路径点；或用「框选」拖动矩形后点「框内路径」自动生成蛇形路线。
2. **设置模式**：选择「定点」「轨迹」或「循环轨迹」。
3. **调整速度**：拖动速度滑块（m/s），或点击快捷档位；需要抖动时打开「速度浮动」。
4. **开始模拟**：点击启动，地图上的模拟点按轨迹移动，实时数据面板同步刷新。
5. **保存轨迹**：可保存当前路径，下次直接读取。

## 系统级定位覆盖（可选）

HarmonyOS 7.0 提供 `testhelper` 命令集，可把 GPX 轨迹注入系统位置服务：

```bash
hdc shell testhelper enable-location-mock
hdc shell testhelper set-mocked-locations /data/local/tmp/track.gpx 1   # 1 = 上报间隔(秒)
hdc shell testhelper disable-location-mock
```

本应用通过 UDP 把「GPX 已就绪」事件广播给 PC 端桥接脚本，由脚本完成推包与命令调用：

```
手机 App（生成 GPX + UDP 广播）
        │  gpxReady / tick / gpxDone
        ▼
pc_bridge.py（监听 UDP 39527）
        │  hdc file recv → hdc file send → testhelper
        ▼
设备系统位置服务（模拟坐标）
```

### 运行桥接脚本

```bash
python pc_bridge.py --port 39527 --device <设备序列号>
```

脚本依次执行：`enable-location-mock` → 从应用沙箱拉取 GPX → 推送至 `/data/local/tmp/track.gpx` → `set-mocked-locations`；收到停止事件后执行 `disable-location-mock` 恢复真实定位。

### UDP 消息协议

| type | 字段 | 说明 |
|---|---|---|
| `tick` | `lat` `lng` `speedMs` `bearing` `time` | 每个模拟周期推送的实时坐标 |
| `gpxReady` | `gpxPath` `pointCount` `intervalSec` `speedMs` `mode` `time` | GPX 已生成，请求开启系统模拟 |
| `gpxDone` | `time` | 停止模拟，恢复真实定位 |

## 重要限制

1. **`testhelper` 位置模拟仅对 debug 签名的应用生效**。release 签名的应用（如应用商店安装的地图、打车类 App）通常仍读取真实定位，这是 HarmonyOS 5 之后为安全与隐私移除「选择模拟位置信息应用」所导致的平台限制，普通应用无法绕过。
2. **GPX 单次最多 1000 个点**，按 `intervalSec` 逐点上报；轨迹播完即停止，需重新下发才能继续。
3. **定位权限**：需要 `ohos.permission.LOCATION` 与 `APPROXIMATELY_LOCATION`，首次使用请允许授权。
4. **地图瓦片**来自第三方在线服务，需设备联网；离线环境地图不可用。
5. 系统级模拟会持续影响整机定位，调试结束请务必执行 `disable-location-mock`。

## 常见问题

- **地图空白**：检查网络与瓦片服务可达性（部分网络环境无法访问默认瓦片源）。
- **位置没变化**：确认已点击「启用模拟」，且 PC 桥接脚本正在运行、设备已连接 `hdc`。
- **`set-mocked-locations` 失败**：检查 GPX 路径是否正确、点数是否超过 1000、设备是否为 HarmonyOS 7.0+。

## 许可证

本项目未附带开源许可证，如需公开仓库请自行补充（例如 MIT / Apache-2.0）。
