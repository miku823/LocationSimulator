import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { GpxBuilder, sampleTrack, SamplePoint } from '../model/GpxBuilder';
import { LatLng } from '../model/GeoUtils';

export interface GpxResult {
  path: string;
  xml: string;
  count: number;
}

/**
 * 将当前轨迹写入 GPX 文件到应用 filesDir。
 * 文件路径通过 hdc file recv 拉取后可推到 /data/local/tmp 供 testhelper 使用。
 */
export class GpxExporter {
  private fileName: string = 'track.gpx';

  exportToFile(
    context: common.UIAbilityContext,
    points: LatLng[],
    speedMs: number,
    intervalSec: number
  ): GpxResult {
    const validInterval: number = Math.max(1, Math.min(3600, Math.round(intervalSec)));
    const samples: SamplePoint[] = sampleTrack(points, speedMs, validInterval);
    const builder: GpxBuilder = new GpxBuilder(samples);
    const xml: string = builder.toXml();

    const dirPath: string = context.filesDir;
    const fullPath: string = dirPath + '/' + this.fileName;

    const file: fileIo.File = fileIo.openSync(fullPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, xml);
    } finally {
      fileIo.closeSync(file);
    }

    const result: GpxResult = { path: fullPath, xml: xml, count: samples.length };
    return result;
  }
}
