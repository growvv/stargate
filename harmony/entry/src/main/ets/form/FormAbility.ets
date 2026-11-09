import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import preferences from '@ohos.data.preferences';
import { CapabilityRepository } from '../data/CapabilityRepository';
import { UsageStore } from '../data/UsageStore';
import { InstallSnapshotStore } from '../data/InstallSnapshotStore';
import { CategoryOrderStore } from '../data/CategoryOrderStore';
import { CardBinding } from './CardBinding';
import type { CardBindingData } from './CardBinding';
import { CardFeedback } from './CardFeedback';
import { RefreshOrchestrator } from './RefreshOrchestrator';

/**
 * 卡片提供方。卡片与提供方独立进程，数据经 formBindingData 推送。
 * 回调只做轻量处理；直达逻辑在 UIAbility 侧（Task 0：FORM_CAN_START_ABILITY=false）。
 *
 * C1 修复：buildRepository() 改 fromContextSync(this.context)，真正读 D5 外部配置 /
 * rawfile 种子（UTF-8 正确解码）；用量改 withPreferencesSync 跨进程共享（I3）。
 * I7：暗色/blur 可用性从 this.context.config.colorMode 与 BLUR 支持推导。
 * I2：CardBinding.failure 由 UIAbility 侧直达失败时推回，卡片显示明确提示。
 *
 * D2 修复（真机 2026-11-07）：失败提示是瞬态的。
 *   - onFormEvent 收到卡片的 'clearFailure' message 时，立即重算并清空 failure；
 *   - 每次推送失败态后，用 setFormNextRefreshTime 排一次确定性刷新，
 *     到点 onUpdateForm 重算时按 TTL 判定自动清除；
 *   - 失败态不写入任何持久存储，定时刷新/force-stop 后不会复活。
 *
 * A2：onUpdateForm 定时刷新 + onFormEvent 诊断/重排，均重算并 formProvider.updateForm。
 */
const FORM_IDENTITY_KEY: string = 'ohos.extra.param.key.form_identity';
const USAGE_STORE_NAME: string = 'atomic_function_usage';
/** 失败态确定性清除刷新：平台最小粒度 1 分钟（够短，且不是常驻）。 */
const FAILURE_CLEAR_MINUTES: number = 1;

export class FormAbility extends FormExtensionAbility {
  /** C1：同步读取真实能力库（外部可替换文件优先，rawfile 种子兜底）。
   *  卡片侧开启 detectBundles：顺带刷新「最近添加」的 first-seen 表。 */
  private buildRepository(): CapabilityRepository {
    return RefreshOrchestrator.effectiveRepository(this.context, true);
  }

  /** I3：跨进程持久化用量句柄（卡片与 UIAbility 共享同一 Preferences 文件）。 */
  private buildUsage(): UsageStore {
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: USAGE_STORE_NAME });
      return UsageStore.withPreferencesSync(pref);
    } catch (_err) {
      return new UsageStore();
    }
  }

  /** I7：暗色从卡片提供的 config 推导；blur 支持为 Task 0 实测 true。 */
  private isDark(): boolean {
    try {
      return this.context.config.colorMode === 0; // ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    } catch (_err) {
      return false;
    }
  }

  /**
   * D2：按 TTL 判定当前是否仍应显示失败提示。
   * 失败产生时刻从「当前绑定的 failureAt」读取；这里用 CardFeedback 的纯逻辑，
   * 避免把一次失败当成永久状态写进 formBindingData。
   */
  private binding(formId: string, failure: string, failureAt: number): CardBindingData {
    const now = Date.now();
    const visible = CardFeedback.visibleAt(failure, failureAt, now);
    // effectiveRepository 已把本次「最近添加」探测结果写回快照；必须先刷新再读回。
    const repo = this.buildRepository();
    const seen = InstallSnapshotStore.fromContextSync(this.context).load().bundleFirstSeen;
    const order = CategoryOrderStore.fromContextSync(this.context).load();
    return CardBinding.compose(repo, this.buildUsage(), now,
      formId, visible ? failure : '', this.isDark(), true, visible ? failureAt : 0, order, seen);
  }

  /** D2：把结果推回卡片；若仍是活跃失败态，排一次确定性清除刷新。 */
  private push(formId: string, data: CardBindingData): void {
    formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    if (data.failure && CardFeedback.needsClearTimer(data.failure, data.failureAt, Date.now())) {
      try {
        formProvider.setFormNextRefreshTime(formId, FAILURE_CLEAR_MINUTES).catch(() => {});
      } catch (_err) {
        // 排不上定时也不影响「卡片侧 TTL + × 主动清除」两条兜底路径。
      }
    }
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    // 记录 formId，供 UIAbility 侧直达失败时 formProvider.updateForm 推回提示（I2）。
    let formId = '';
    try {
      const id = want?.parameters?.[FORM_IDENTITY_KEY] as string;
      formId = id ?? '';
    } catch (_err) {
      formId = '';
    }
    return formBindingData.createFormBindingData(this.binding(formId, '', 0));
  }

  onFormEvent(formId: string, message: string): void {
    // 'message' 链：卡片「×」主动清除失败提示 / A2 点击即重排。
    // D2：无论 message 内容为何，重算时都不再把过期失败态带回卡片。
    console.info('FormAbility.onFormEvent: ' + formId + ' / ' + message);
    this.push(formId, this.binding(formId, '', 0));
  }

  onUpdateForm(formId: string): void {
    // A2 定时刷新兜底 + D2 失败态确定性清除：重算时按 TTL 判定，过期即清空。
    // 失败态本身不持久化，这里传空 failure，卡片只依赖当前绑定的 failureAt 判定。
    this.push(formId, this.binding(formId, '', 0));
  }

  onRemoveForm(formId: string): void {
  }
}

export default FormAbility;
