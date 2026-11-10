import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'LocationSimulator';

/**
 * 封装长时任务（location 类型），使模拟在应用退到后台后仍继续推进。
 */
export class BackgroundRunner {
  private active: boolean = false;

  isActive(): boolean {
    return this.active;
  }

  async start(context: common.UIAbilityContext, bundleName: string, abilityName: string): Promise<void> {
    if (this.active) {
      return;
    }
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: bundleName,
          abilityName: abilityName
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    const agent: WantAgent = await wantAgent.getWantAgent(info);
    await backgroundTaskManager.startBackgroundRunning(
      context, backgroundTaskManager.BackgroundMode.LOCATION, agent);
    this.active = true;
    hilog.info(DOMAIN, TAG, 'continuous task started');
  }

  async stop(context: common.UIAbilityContext): Promise<void> {
    if (!this.active) {
      return;
    }
    await backgroundTaskManager.stopBackgroundRunning(context);
    this.active = false;
    hilog.info(DOMAIN, TAG, 'continuous task stopped');
  }
}
