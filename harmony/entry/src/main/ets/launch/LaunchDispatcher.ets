import type { AtomicFunction, Route } from '../model/AtomicFunction';
import type { LaunchResult, StartAbilityFn, UsageRecorder, VerticalStarterFn, LinkOpenerFn } from './LaunchResult';

/**
 * 直达分发器（产品 Spec §7 三条硬约束）：
 *  1. 运行时只用 fn.route **单条最可靠路由**（无 routes[] 遍历、无多路由降级）；
 *  2. 失败即返回 ok=false, reason='NO_AVAILABLE_ENTRY'，**不回退 App 首页**；
 *  3. 「换方案」只在工程/预研层，运行时不做降级。
 *
 * Want 构造按 route.kind 一次生成；调一次注入的 starter（生产侧传
 * UIAbilityContext.startAbility 包装，测试侧传替身）。成功则记录用量（D4：内部输入）。
 *
 * 形态 A S3：`vertical` 是唯一例外 —— 系统按 type+sceneType 匹配目标 App，
 * 走注入的 verticalStarter（startAbilityByType），**不构造 Want、不调 starter**。
 * 该分支不把 fn.bundleName 当目标包使用（卡片的 bundleName 归属本应用）。
 */
export class LaunchDispatcher {
  static async launch(fn: AtomicFunction, starter?: StartAbilityFn, usage?: UsageRecorder,
    verticalStarter?: VerticalStarterFn, linkOpener?: LinkOpenerFn): Promise<LaunchResult> {
    let ok = false;
    if (fn.route.kind === 'vertical') {
      const p = fn.route.parameters ?? {};
      const vtype = p['verticalType'];
      // 缺 type 视为不可用入口；失败即报告，绝不退化成 startAbility/首页。
      if (typeof vtype === 'string' && vtype.length > 0 && verticalStarter) {
        const wantParam: Record<string, Object> = {};
        for (const k of Object.keys(p)) if (k !== 'verticalType') wantParam[k] = p[k] as Object;
        ok = await verticalStarter(vtype, wantParam);
      }
    } else if ((fn.route.kind === 'deeplink' || fn.route.kind === 'applinking')
      && linkOpener !== undefined && (fn.route.uri ?? '').length > 0) {
      // 链接类路由走系统的 openLink：由它按目标 App 声明的 skill 匹配。
      // 自己拼隐式 Want 调 startAbility 会被生态规则拦下（见 LinkOpenerFn 注释）。
      ok = await linkOpener(fn.route.uri ?? '');
    } else {
      const want = LaunchDispatcher.buildWant(fn.route, fn.bundleName);
      // 无 starter（未注入真实启动能力）→ 明确失败，不静默、不回退。
      ok = starter ? await starter(want) : false;
    }
    if (ok) {
      if (usage) await usage.record(fn.id, Date.now());
      const success: LaunchResult = { ok: true, functionId: fn.id };
      return success;
    }
    const failure: LaunchResult = { ok: false, functionId: fn.id, reason: 'NO_AVAILABLE_ENTRY' };
    return failure;
  }

  /**
   * 跨 App 打开链接时必须携带的 action。
   *
   * 真机 2026-11-11：卡片点「微博」直接退出，AMS 日志
   *   [implicit_start_processor.cpp340]failed, uri:sinaweibo-<private>
   * 只带 bundleName + uri 的 Want 在应用侧走**隐式**匹配，而目标 App 的
   * browsable skill 声明的是 actions=[ohos.want.action.viewData]；action 为空
   * 就匹配不上 —— 入口看着能点，点了打不开。
   *
   * 真机对照（同一 uri、同一台机器）：补上该 action 后微博 / QQ音乐 / 支付宝 /
   * 百度地图全部落到目标前台；不补则只有部分 App 能开。
   */
  private static readonly LINK_ACTION: string = 'ohos.want.action.viewData';

  /**
   * 由单条 Route 构造一次 Want；四种 kind 各一条路径，绝不拼第二条。
   * I1：每条路径都带 `bundleName` 使 Want **显式**——裸 uri 会被任意 App 认领并
   * 落到首页/系统弹窗，却被 `aa start` 报「成功」，违反「失败即报告」硬约束。
   * 显式化不新增第二条路由、不回退首页，只是收紧路由形状（A3 验证仍以原子页落点为准）。
   */
  private static buildWant(route: Route, bundleName: string): Record<string, Object> {
    const want: Record<string, Object> = {};
    want['bundleName'] = bundleName; // 所有 kind 都显式指向目标包
    if (route.kind === 'deeplink' || route.kind === 'applinking') {
      want['uri'] = route.uri ?? '';
      // 目录里写明的 action 优先；没有就用跨 App 打开链接的标准 action。
      // 缺了它，目标 App 的 browsable skill 匹配不上，隐式启动直接失败。
      const explicit: Object | undefined = route.parameters?.['action'];
      want['action'] = (typeof explicit === 'string' && explicit.length > 0)
        ? explicit : LaunchDispatcher.LINK_ACTION;
      if (route.parameters) want['parameters'] = route.parameters;
    } else if (route.kind === 'shortcut-param') {
      want['abilityName'] = route.abilityName ?? '';
      want['moduleName'] = route.moduleName ?? '';
      if (route.parameters) want['parameters'] = route.parameters;
    } else { // 'want'
      want['uri'] = route.uri ?? '';
      want['action'] = route.parameters?.['action'] ?? '';
      if (route.abilityName) want['abilityName'] = route.abilityName;
      if (route.moduleName) want['moduleName'] = route.moduleName;
    }
    return want;
  }

  /**
   * 失败反馈：标记失效 + 触发「暂无可用直达入口」提示。
   * 实际 UI（小圆点 / 轻提示）由 FormAbility / 页面侧按此结果渲染；本方法只归一化文案。
   */
  static onFailure(fn: AtomicFunction, r: LaunchResult): string {
    return '『' + fn.label + '』暂无可用直达入口';
  }
}

export default LaunchDispatcher;
