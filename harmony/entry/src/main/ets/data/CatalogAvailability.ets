import type { AtomicFunction, Route } from '../model/AtomicFunction';
import type { RouteProbe, PresenceProbe, LinkStateProbe } from './InstalledProbe';

/**
 * 入口可用性判定（2026-11-11，换设备真机验证后新增）。
 *
 * 真机问题：能力目录是随 HAP 打包的静态 JSON，包含多个 App 的入口。换一台
 * 手机后，没装 WPS / 懂球帝，卡片和搜索页里照样出现它们的图标；点下去
 * `startAbility` 失败，用户看到「暂无可用直达入口」—— 入口看着能点，实际
 * 点不开。上架应用不能这样：**目录必须按当前设备的真实安装状态收敛**。
 *
 * 判定顺序（先准后细）：
 *  1. **安装态**：按 bundleName 问系统（PresenceProbe，getBundleInfoSync）。
 *     明确「未安装」→ 该 App 的全部条目剔除。
 *  2. **链接可达性**：安装态查不到时（无权限 / 系统异常），退回 canOpenLink
 *     探该 App 的代表 scheme。只有系统明确回答「无人认领」才剔除。
 *  3. **入口级**：App 在，再按条目自己的 scheme 探一次；只有明确「无人认领」
 *     才剔除这一条。通用 scheme（file:// / https:// / mailto:// 等）任何 App
 *     都可能响应，探不出归属，不做入口级判定。
 *
 * 关键：**异常 ≠ 不可用**。canOpenLink 对不完整链接（`alipays://`）抛 17700055、
 * 对未登记进 querySchemes 的 scheme 抛 17700056；把这些异常当成 false 会把
 * 已安装的支付宝整包剔除（真机踩到：搜索「支付宝」空结果）。因此探针是三态的，
 * 只有 'closed' 才代表「系统确认无人认领」。
 *
 * 安全阀：如果一次判定都没能得出「可用 / 未安装」的明确结论，必须 **fail-open**，
 * 原样返回全部条目 —— 少配一个 manifest 字段最多退化成旧行为，而不是把目录清空。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */

/** 全系统通用 scheme：不能用来判断某个 App 是否安装。 */
const GENERIC_SCHEMES: string[] = [
  'file', 'https', 'http', 'mailto', 'tel', 'sms', 'geo', 'market', 'intent',
  'storage', 'systemnav', 'maps', 'settings', 'setting'
];

/** 一条入口的可用性判定结果。 */
export interface AvailabilityResult {
  /** 当前设备上确认可用的条目 id（保持输入顺序）。 */
  availableIds: string[];
  /** 判定为未安装的 bundleName（供诊断与测试）。 */
  missingBundles: string[];
  /** 实际做过判定的 App 数。 */
  probedBundles: number;
  /** 判定结果是否可信；false = 探针整体失效，调用方应 fail-open。 */
  probeAvailable: boolean;
  /** 被剔除的条目 id（整包剔除 + 单条剔除），供诊断。 */
  droppedIds: string[];
  /** 判定来源：'presence' = 包名查询，'link' = 链接探测，'none' = 未判定。 */
  source: string;
}

/** 从 uri 中取 scheme（小写）；无 scheme 返回 ''。 */
export function schemeOf(uri: string): string {
  if (!uri) return '';
  const at: number = uri.indexOf('://');
  if (at <= 0) return '';
  const raw: string = uri.substring(0, at).toLowerCase();
  // scheme 必须字母开头（过滤 '{{SECRET_x}}://' 这类占位数据）。
  if (!/^[a-z][a-z0-9+.-]*$/.test(raw)) return '';
  return raw;
}

/** 该 scheme 是否具有 App 归属（能用来判断安装状态）。 */
export function isSpecificScheme(scheme: string): boolean {
  if (!scheme) return false;
  return GENERIC_SCHEMES.indexOf(scheme) < 0;
}

export class CatalogAvailability {
  /**
   * 评估当前设备上哪些条目可用。
   * @param items    待判定条目（调用方通常传 L0 条目）
   * @param probe    链接探针（生产侧 BundleSchemeProbe；若实现 LinkStateProbe 则用三态）
   * @param presence 安装态探针（可缺省；缺省则全部走链接探测）
   */
  static evaluate(items: AtomicFunction[], probe: RouteProbe,
    presence?: PresenceProbe): AvailabilityResult {
    const none: AvailabilityResult = {
      availableIds: [], missingBundles: [], probedBundles: 0,
      probeAvailable: false, droppedIds: [], source: 'none'
    };
    if (!items || items.length === 0) return none;

    // ── 按 bundle 归组 ────────────────────────────────────────────────
    const byBundle: Map<string, AtomicFunction[]> = new Map<string, AtomicFunction[]>();
    for (const f of items) {
      const key: string = f.bundleName ? f.bundleName : '';
      const bucket: AtomicFunction[] | undefined = byBundle.get(key);
      if (bucket) bucket.push(f);
      else byBundle.set(key, [f]);
    }

    // ── App 级判定：先问安装态，再退回代表 scheme 探测 ─────────────────
    const missing: Set<string> = new Set<string>();
    let presenceAnswered: number = 0;
    let linkProbed: number = 0;
    let linkConclusive: number = 0;

    const bundles: string[] = [];
    byBundle.forEach((_list: AtomicFunction[], bundle: string) => { bundles.push(bundle); });
    bundles.sort();

    for (const bundle of bundles) {
      let state: boolean | undefined = undefined;
      if (presence) {
        try {
          state = presence.installed(bundle);
        } catch (_err) {
          state = undefined;
        }
        if (state !== undefined) presenceAnswered += 1;
      }
      if (state === true) continue;   // 已安装
      if (state === false) {          // 明确未安装
        missing.add(bundle);
        continue;
      }
      // 安装态未知：用该 App 最有辨识度的一条**真实路由**探测。
      // 不能把 scheme 拼成 `alipays://` 再探 —— 系统对只有 scheme 的链接
      // 可能直接判 false（真机实测：支付宝已安装却被判不可用）。
      const list: AtomicFunction[] = byBundle.get(bundle) ?? [];
      const rep: AtomicFunction | undefined = CatalogAvailability.representativeEntry(list);
      if (rep === undefined) {
        // 纯 vertical / shortcut-param，无 scheme 可探：无法判定，按可用处理。
        continue;
      }
      linkProbed += 1;
      const link: string = CatalogAvailability.stateOfRoute(probe, rep.route);
      if (link !== 'unknown') linkConclusive += 1;
      // 只有系统明确说「无人认领」才判未安装；'unknown' 不能当未安装。
      if (link === 'closed') missing.add(bundle);
    }

    // ── 安全阀：一次明确结论都没有 → 探针失效，fail-open ───────────────
    const answered: boolean = presenceAnswered > 0 || linkConclusive > 0;
    if (!answered) {
      const all: string[] = [];
      for (const f of items) all.push(f.id);
      return {
        availableIds: all,
        missingBundles: [],
        probedBundles: bundles.length,
        probeAvailable: false,
        droppedIds: [],
        source: 'none'
      };
    }

    // ── 入口级判定（仅对已安装 App 且有辨识度 scheme 的条目） ──────────
    const availableIds: string[] = [];
    const droppedIds: string[] = [];
    for (const f of items) {
      const bundle: string = f.bundleName ? f.bundleName : '';
      if (missing.has(bundle)) {
        droppedIds.push(f.id);
        continue;
      }
      const scheme: string = CatalogAvailability.routeScheme(f.route);
      if (!isSpecificScheme(scheme)) {
        availableIds.push(f.id);
        continue;
      }
      // 只有明确「无人认领」才剔除这一条；探测失败保持可用。
      const link: string = CatalogAvailability.stateOfRoute(probe, f.route);
      if (link === 'closed') droppedIds.push(f.id);
      else availableIds.push(f.id);
    }

    const missingBundles: string[] = [];
    missing.forEach((b: string) => missingBundles.push(b));
    missingBundles.sort();
    return {
      availableIds: availableIds,
      missingBundles: missingBundles,
      probedBundles: bundles.length,
      probeAvailable: true,
      droppedIds: droppedIds,
      source: presenceAnswered > 0 ? 'presence' : 'link'
    };
  }

  /** 三态探测：探针实现 LinkStateProbe 就用三态，否则用布尔值近似。 */
  static stateOfRoute(probe: RouteProbe, route: Route): string {
    const stateful: LinkStateProbe | undefined = probe as LinkStateProbe;
    if (stateful !== undefined && typeof stateful.linkState === 'function') {
      try {
        return stateful.linkState(route);
      } catch (_err) {
        return 'unknown';
      }
    }
    try {
      return probe.canOpenRoute(route) ? 'open' : 'closed';
    } catch (_err) {
      // 老式布尔探针抛异常同样代表「无法判定」。
      return 'unknown';
    }
  }

  /**
   * 该 App 最有辨识度的一条**完整路由**（跳过通用 scheme）。
   * 用真实 uri 探测，不要自己拼 `scheme://`：系统对只有 scheme 的链接
   * 可能判 false，会把已安装的 App 误判成未安装。
   */
  static representativeEntry(list: AtomicFunction[]): AtomicFunction | undefined {
    for (const f of list) {
      const s: string = CatalogAvailability.routeScheme(f.route);
      if (isSpecificScheme(s)) return f;
    }
    return undefined;
  }

  /** 该 App 条目里最有辨识度的一条 scheme（跳过通用 scheme）。 */
  static representativeScheme(list: AtomicFunction[]): string {
    const rep: AtomicFunction | undefined = CatalogAvailability.representativeEntry(list);
    return rep === undefined ? '' : CatalogAvailability.routeScheme(rep.route);
  }

  /** 条目的 scheme（vertical 无 uri → ''）。 */
  static routeScheme(route: Route): string {
    if (!route) return '';
    return schemeOf(route.uri ?? '');
  }
}

export default CatalogAvailability;
