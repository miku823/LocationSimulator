import { common } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import { LatLng } from './GeoUtils';

/**
 * 路线存档：基于应用级 Preferences 持久化点位序列。
 * 存储格式：键 route_<名称>，值 "lat,lng;lat,lng;..."（纯字符串，避免 JSON 反序列化类型问题）。
 */
export interface RouteMeta {
  name: string;
  count: number;
}

const STORE_NAME: string = 'route_store';
const KEY_PREFIX: string = 'route_';

function getStore(context: common.UIAbilityContext): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: STORE_NAME });
}

export function encodePoints(points: LatLng[]): string {
  const parts: string[] = [];
  for (let i = 0; i < points.length; i++) {
    parts.push(points[i].latitude.toFixed(6) + ',' + points[i].longitude.toFixed(6));
  }
  return parts.join(';');
}

export function decodePoints(text: string): LatLng[] {
  const out: LatLng[] = [];
  if (text.length === 0) {
    return out;
  }
  const parts: string[] = text.split(';');
  for (let i = 0; i < parts.length; i++) {
    const pair: string[] = parts[i].split(',');
    if (pair.length === 2) {
      const lat: number = Number(pair[0]);
      const lng: number = Number(pair[1]);
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        out.push({ latitude: lat, longitude: lng });
      }
    }
  }
  return out;
}

export function saveRoute(context: common.UIAbilityContext, name: string, points: LatLng[]): void {
  const store: preferences.Preferences = getStore(context);
  store.putSync(KEY_PREFIX + name, encodePoints(points));
  store.flush().catch(() => {
    // flush 异步失败不影响当前会话读取
  });
}

export function getRoutePoints(context: common.UIAbilityContext, name: string): LatLng[] {
  const store: preferences.Preferences = getStore(context);
  const value: preferences.ValueType = store.getSync(KEY_PREFIX + name, '');
  if (typeof value === 'string') {
    return decodePoints(value);
  }
  return [];
}

export function listRoutes(context: common.UIAbilityContext): RouteMeta[] {
  const store: preferences.Preferences = getStore(context);
  const all = store.getAllSync() as Record<string, preferences.ValueType>;
  const keys: string[] = Object.keys(all);
  const metas: RouteMeta[] = [];
  for (let i = 0; i < keys.length; i++) {
    const key: string = keys[i];
    if (key.indexOf(KEY_PREFIX) !== 0) {
      continue;
    }
    const value: preferences.ValueType = all[key];
    if (typeof value === 'string') {
      const count: number = decodePoints(value).length;
      if (count > 0) {
        metas.push({ name: key.substring(KEY_PREFIX.length), count: count });
      }
    }
  }
  // 名称含日期时间，倒序即最新在前
  metas.sort((a: RouteMeta, b: RouteMeta): number => {
    return a.name < b.name ? 1 : -1;
  });
  return metas;
}

export function deleteRoute(context: common.UIAbilityContext, name: string): void {
  const store: preferences.Preferences = getStore(context);
  store.deleteSync(KEY_PREFIX + name);
  store.flush().catch(() => {
    // flush 异步失败不影响当前会话删除
  });
}
