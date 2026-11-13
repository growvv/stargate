import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 目录准入的最后一道：只写到 scheme 的链接一律剔除（2026-11-12 用户拍板）。
 *
 * 真机规律（2026-11-12，逐条验证）：URI 只写到 scheme（`xxx://`，后面没有
 * host、没有 path）时，系统只能把目标 App 拉到**默认首页**，落不到标签承诺
 * 的功能页：
 *
 *   抖音「付款」    dypay1128://   → 抖音首页信息流
 *   QQ音乐「存储空间」qqmusic://     → QQ音乐开屏广告
 *   支付宝「登录」   apmqpdispatch:// → 黑屏（App 起不来）
 *   电子邮件「写邮件」 mailto://       → 隐私声明弹窗
 *   华为阅读「分享」  file://          → 隐私同意页
 *
 * 这些入口点得开，但兑现不了「付款 / 存储空间 / 登录」这类功能承诺 —— 属于
 * 「看着能点、点开不是那个东西」。用户政策：**这类条目直接删除**，不做改名、
 * 不做降级（改名会留下大量「打开 X」噪声，桌面本身就有 App 图标）。
 *
 * 种子能力库（capabilities.json）已经按这条政策删干净；本类仍作为运行时闸门，
 * 防止 D5 外部可替换配置（`hdc push capabilities.json`）再塞回这类条目。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */
export interface RouteHonestyResult {
  items: AtomicFunction[];
  /** 被剔除的条目 id（供诊断与测试）。 */
  dropped: string[];
}

export class RouteHonesty {
  /**
   * URI 是否只写到 scheme：`qqmusic://`、`mailto://`、`alipay:` 都算。
   * `https://music.qq.com/`、`sinaweibo://settings/cache` 不算（有 host / path）。
   */
  static isBareScheme(uri: string): boolean {
    if (!uri) return false;
    const colon = uri.indexOf(':');
    if (colon <= 0) return false;
    // scheme 之后允许 `//`，其余必须为空才算「只写到 scheme」。
    let rest = uri.substring(colon + 1);
    while (rest.startsWith('/')) rest = rest.substring(1);
    return rest.length === 0;
  }

  /** 该条目的路由是否只能打开 App 首页（链接类路由且 URI 只写到 scheme）。 */
  static opensHomeOnly(fn: AtomicFunction): boolean {
    if (!fn || !fn.route) return false;
    if (fn.route.kind !== 'deeplink' && fn.route.kind !== 'applinking') return false;
    return RouteHonesty.isBareScheme(fn.route.uri ?? '');
  }

  /** 剔除只能打开 App 首页的条目；不修改入参，保持输入顺序。 */
  static apply(items: AtomicFunction[]): RouteHonestyResult {
    const dropped: string[] = [];
    const kept: AtomicFunction[] = [];
    for (const fn of items) {
      if (RouteHonesty.opensHomeOnly(fn)) {
        dropped.push(fn.id);
        continue;
      }
      kept.push(fn);
    }
    return { items: kept, dropped: dropped };
  }
}

export default RouteHonesty;
