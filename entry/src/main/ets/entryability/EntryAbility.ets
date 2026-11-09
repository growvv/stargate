import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import formProvider from '@ohos.app.form.formProvider';
import formBindingData from '@ohos.app.form.formBindingData';
import preferences from '@ohos.data.preferences';
import { UsageStore } from '../data/UsageStore';
import { InstallSnapshotStore } from '../data/InstallSnapshotStore';
import { CategoryOrderStore } from '../data/CategoryOrderStore';
import { LaunchDispatcher } from '../launch/LaunchDispatcher';
import { createVerticalStarter } from '../launch/VerticalStarter';
import { ConfigAccess } from '../data/ConfigAccess';
import { CardBinding } from '../form/CardBinding';
import { PageRouter } from '../pages/PageRouter';
import type { LaunchResult } from '../launch/LaunchResult';
import { RefreshOrchestrator } from '../form/RefreshOrchestrator';

/**
 * 非 Launcher 入口：卡片是唯一常驻入口，本 Ability 只承载被 router 拉起的
 * 分类页 / 全量列表页 / 配置页（无 entity.system.home，不暴露产品主 UI）。
 *
 * C1 修复：runLaunch 与页面注入改 fromContextSync，读真实 D5 能力库。
 * I2 修复：直达失败不再只 console.error + terminateSelf，而是把 failure 文案
 *   经 formProvider.updateForm 推回卡片显示（『X』暂无可用直达入口）。
 * I3 修复：用量走 withPreferencesSync 持久化，成功后 formProvider.updateForm 触发重排。
 * I5 修复：formConfigAbility 的 Want（无 page）经 ConfigAccess.pageForFormConfig → config 页。
 */
const FORM_IDENTITY_KEY: string = 'ohos.extra.param.key.form_identity';
const USAGE_STORE_NAME: string = 'atomic_function_usage';

export default class EntryAbility extends UIAbility {
  private page: string = 'index';
  private functionId: string = '';
  private formId: string = '';
  private category: string = '';
  private pageStorage: LocalStorage = new LocalStorage();
  private windowStage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const previous = this.page;
    const previousCategory = this.category;
    this.applyWant(want);
    if (this.page === 'launch') {
      this.runLaunch();
      return;
    }
    // 真机验证：Ability 已在前台时，新 router Want 只走 onNewWant。若目标页
    // 变了却不重新 loadContent，用户点「配置」仍看到上一次的「全量列表页」。
    // 2026-11-09 修复：分类页同路径不同分类（支付 → 购物）也必须重载。
    if (this.windowStage &&
      PageRouter.needsContentReloadForTarget(previous, this.page, previousCategory, this.category)) {
      this.loadForPage(this.windowStage);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    if (this.page === 'launch') {
      // 直达不需窗口：在后台完成一次 Want 后自行结束。
      this.runLaunch();
      return;
    }
    this.loadForPage(windowStage);
  }

  private applyWant(want: Want): void {
    const params = want?.parameters;
    const page = params ? params['page'] as string : undefined;
    const category = params ? params['category'] as string : undefined;
    const functionId = params ? params['functionId'] as string : undefined;
    // 卡片显式带 formId（从自身 binding 读出）优先，系统注入的 form_identity 兜底。
    const explicitFormId = params ? params['formId'] as string : undefined;
    const systemFormId = params ? params[FORM_IDENTITY_KEY] as string : undefined;
    // I5：formConfigAbility 的 Want 不带 page，缺省落到 config 页（不再进 Index 死占位）。
    this.page = page ? page : ConfigAccess.pageForFormConfig('');
    this.functionId = functionId ?? '';
    this.formId = explicitFormId ?? systemFormId ?? '';
    this.category = category ?? '';
    this.pageStorage.setOrCreate('category', this.category);
  }

  private loadForPage(windowStage: window.WindowStage): void {
    let path = 'pages/Index';
    if (this.page === 'category') path = 'pages/CategoryPage';
    else if (this.page === 'all') path = 'pages/AllFunctionsPage';
    else if (this.page === 'config') path = 'pages/ConfigPage'; // B3′ 最小配置
    else if (this.page === 'explorer') path = 'pages/CapabilityExplorerPage';
    windowStage.loadContent(path, this.pageStorage, (err) => {
      if (err.code) { console.error('loadContent failed: ' + JSON.stringify(err)); }
    });
  }

  /** I3：与 FormAbility 共享同一 Preferences 文件的持久化用量。 */
  private buildUsage(): UsageStore {
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: USAGE_STORE_NAME });
      return UsageStore.withPreferencesSync(pref);
    } catch (_err) {
      return new UsageStore();
    }
  }

  /** I2：把失败/成功结果推回卡片（failure 字段 → 卡片显示明确提示 + 失效标记）。
   *  D2：失败带 failureAt 时间戳，卡片按 TTL 显示、过期自动消失，不再常驻。 */
  private pushCardResult(failure: string): void {
    if (!this.formId) return;
    try {
      const now = Date.now();
      const repo = RefreshOrchestrator.effectiveRepository(this.context, true);
      const seen = InstallSnapshotStore.fromContextSync(this.context).load().bundleFirstSeen;
      const order = CategoryOrderStore.fromContextSync(this.context).load();
      const data = CardBinding.compose(repo, this.buildUsage(), now,
        this.formId, failure, false, true, failure ? now : 0, order, seen);
      formProvider.updateForm(this.formId, formBindingData.createFormBindingData(data));
      if (failure) {
        // D2：排一次确定性刷新，到点由 FormAbility.onUpdateForm 按 TTL 清除。
        try {
          formProvider.setFormNextRefreshTime(this.formId, 1).catch(() => {});
        } catch (_err) {
          // 卡片侧 TTL 与「×」主动清除仍可作为兜底。
        }
      }
    } catch (_err) {
      console.error('NO_AVAILABLE_ENTRY: card feedback push failed');
    }
  }

  /** UIAbility 侧直达：单次 Want、失败明确报告并推回卡片、绝不回退首页。 */
  private async runLaunch(): Promise<void> {
    const repo = RefreshOrchestrator.effectiveRepository(this.context);
    const fn = await repo.get(this.functionId);
    if (!fn) {
      console.error('NO_AVAILABLE_ENTRY: functionId not found ' + this.functionId);
      this.pushCardResult('暂无可用直达入口');
      await this.context.terminateSelf();
      return;
    }
    const ctx = this.context;
    const starter = async (want: Object) => {
      try {
        await ctx.startAbility(want);
        return true;
      } catch (_err) {
        return false;
      }
    };
    const verticalStarter = createVerticalStarter(ctx);
    const r: LaunchResult = await LaunchDispatcher.launch(fn, starter, this.buildUsage(), verticalStarter);
    if (!r.ok) {
      console.error('NO_AVAILABLE_ENTRY: ' + LaunchDispatcher.onFailure(fn, r));
      this.pushCardResult(LaunchDispatcher.onFailure(fn, r)); // I2：用户可见
    } else {
      this.pushCardResult(''); // I3/A2：成功后触发卡片重排（用量已持久化）
    }
    await this.context.terminateSelf();
  }
}
