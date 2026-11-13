import bundleManager from '@ohos.bundle.bundleManager';
import type { AppTemplateEntry } from './AppTemplateCatalog';
import type { AtomicFunction, Route } from '../model/AtomicFunction';

/** The only SDK boundary used for install awareness. */
export interface SchemeProbe {
  canOpen(scheme: string): boolean;
}

/** 检测「能力库条目所属 App 是否仍能被系统打开」的探针（InstallSnapshot 用）。 */
export interface RouteProbe {
  canOpenRoute(route: Route): boolean;
}

/**
 * 三态链接探针。
 *
 * 为什么需要三态（2026-11-11 真机踩到）：`canOpenLink` 对「没有 App 接得住」
 * 返回 false，但对**格式不完整**的链接（例如只有 scheme 的 `alipays://`）
 * 直接抛 17700055，对没登记进 querySchemes 的 scheme 抛 17700056。
 * 旧代码把异常一律当成 false，于是已安装的支付宝被整包判成「不可用」，
 * 搜索「支付宝」得到空结果。异常代表**不知道**，不能当成「不可用」。
 */
export interface LinkStateProbe extends RouteProbe {
  /** 'open' = 系统确认可打开；'closed' = 系统确认无人认领；'unknown' = 探测失败。 */
  linkState(route: Route): string;
}

/**
 * 安装态探针：直接问系统「这个包装了没有」。
 *
 * 为什么需要它（2026-11-11 换设备真机验证）：`canOpenLink` 只能回答
 * 「这个链接有没有 App 接得住」，遇到没有可归属 scheme 的条目（file://、纯
 * vertical、只声明 shortcut 的 App）就无法判断安装状态；而且它要求 scheme
 * 已写进 module.json5 的 querySchemes，漏一个就抛 17700056。
 * `getBundleInfoSync` 直接按包名查安装状态，语义准确、不依赖 scheme 声明，
 * 只需要普通级权限 ohos.permission.GET_BUNDLE_INFO。
 *
 * 返回值三态：true = 已安装；false = 未安装；undefined = 查询失败（无权限 /
 * 系统异常），调用方应退回链接探测或 fail-open。
 */
export interface PresenceProbe {
  installed(bundleName: string): boolean | undefined;
}

export class BundleSchemeProbe implements SchemeProbe, RouteProbe, LinkStateProbe {
  canOpen(scheme: string): boolean {
    if (!scheme) return false;
    try {
      // Templates may store a bare scheme ("weixin") or a qualified link.
      // canOpenLink consumes a link, so add only the minimal delimiter for a
      // bare scheme and preserve a caller-supplied path/query verbatim.
      const link = scheme.indexOf('://') >= 0 ? scheme : scheme + '://';
      return bundleManager.canOpenLink(link);
    } catch (_err) {
      return false;
    }
  }

  canOpenRoute(route: Route): boolean {
    return this.linkState(route) === 'open';
  }

  linkState(route: Route): string {
    const uri: string = route.uri ?? '';
    if (!uri) return 'unknown';
    try {
      return bundleManager.canOpenLink(uri) ? 'open' : 'closed';
    } catch (_err) {
      // 17700055（链接不完整）/ 17700056（scheme 未登记）等异常都表示「无法判定」，
      // 绝不能当成「不可用」，否则会把已安装 App 的条目整包剔除。
      return 'unknown';
    }
  }
}

/**
 * 生产侧安装态探针（bundleManager.getBundleInfoSync）。
 *
 * 卡片刷新与页面加载都会走这里，同一进程内做 30s 记忆化：一次刷新会问
 * 39 个包，逐次跨进程查询没有必要；用户刚装/刚卸载的 App 最多 30s 后生效，
 * 而且「最近添加」本来就按刷新周期统计，不存在实时性要求。
 */
export class BundlePresenceProbe implements PresenceProbe {
  private static readonly TTL_MS: number = 30000;
  private cache: Map<string, boolean> = new Map<string, boolean>();
  private cachedAt: number = 0;

  installed(bundleName: string): boolean | undefined {
    if (!bundleName) return undefined;
    const now: number = Date.now();
    if (now - this.cachedAt > BundlePresenceProbe.TTL_MS) {
      this.cache.clear();
      this.cachedAt = now;
    }
    const hit: boolean | undefined = this.cache.get(bundleName);
    if (hit !== undefined) return hit;
    let value: boolean | undefined = undefined;
    try {
      // GET_BUNDLE_INFO_DEFAULT = 0：只查存在性，不拉 ability 列表，最快。
      bundleManager.getBundleInfoSync(bundleName, 0);
      value = true;
    } catch (err) {
      // 17700001 = 包不存在；201 = 无权限。无权限时必须返回 undefined，
      // 让调用方 fail-open，而不是把所有条目误判为「未安装」。
      const code: number = (err as Record<string, Object>)['code'] as number;
      value = code === 17700001 ? false : undefined;
    }
    if (value !== undefined) this.cache.set(bundleName, value);
    return value;
  }
}

export class InstalledProbe {
  static installedIds(templates: AppTemplateEntry[], probe: SchemeProbe): string[] {
    const out: string[] = [];
    for (const template of templates) {
      if (!template.scheme) continue;
      try {
        if (probe.canOpen(template.scheme)) out.push(template.id);
      } catch (_err) {
        // A single missing/undeclared scheme must not abort the batch.
      }
    }
    return out.sort();
  }

  /**
   * 能力库条目 → 仍可被系统打开的 bundleName 列表（用于「最近添加」）。
   * 一个 App 的多条功能只尝试到第一条成功为止；全部失败则视为已卸载。
   */
  static detectedBundles(items: AtomicFunction[], probe: RouteProbe): string[] {
    const out: string[] = [];
    const confirmed: Set<string> = new Set<string>();
    for (const f of items) {
      if (!f.bundleName || confirmed.has(f.bundleName)) continue;
      try {
        if (probe.canOpenRoute(f.route)) {
          confirmed.add(f.bundleName);
          out.push(f.bundleName);
        }
      } catch (_err) {
        // 单条路由探测失败不阻断其余 App；同一 App 的后续功能仍会继续尝试。
      }
    }
    return out.sort();
  }

  /**
   * 安装态探测（优先）：按包名直接问系统，覆盖没有可归属 scheme 的条目。
   * presence 返回 undefined 的 App 不算「已检测到」—— 宁可少报一个最近添加，
   * 也不把查不到状态的 App 当成新装的。
   */
  static detectedBundlesByPresence(items: AtomicFunction[], presence: PresenceProbe): string[] {
    const out: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (const f of items) {
      if (!f.bundleName || seen.has(f.bundleName)) continue;
      seen.add(f.bundleName);
      try {
        if (presence.installed(f.bundleName) === true) out.push(f.bundleName);
      } catch (_err) {
        // 单个包查询失败不影响其余包。
      }
    }
    return out.sort();
  }

  /**
   * 「最近添加」的 App 探测：**有明确安装态结论就用它，否则退回链接探测**。
   *
   * 真机 2026-11-11（换到手机上验证时发现）：`getBundleInfoSync` 对**本机所有
   * 包**都返回 8521226 —— 连已安装的支付宝、微博也一样。SDK 对这个接口写得很
   * 直白：
   *   "The application requires to be a system application when requesting the
   *    permission of ohos.permission.GET_BUNDLE_INFO."
   * 我们是普通三方应用（上架形态），所以安装态探针**永远是 undefined**。
   *
   * 旧实现只要传了 presence 就只用它，于是「最近添加」一个 App 也探测不到，
   * 卡片永远显示目录尾部的默认填充 —— 用户装了新 App 也不会出现。这正好是
   * 「能不能主动发现能力」的答案：不能。
   *
   * 修法：presence 至少给出一条明确结论（true/false）才以它为准；一条都没有
   * （三方应用常态）就退回 canOpenLink 链接探测，至少能认出带 scheme 的 App。
   */
  static detectedBundlesBest(items: AtomicFunction[], presence: PresenceProbe,
    routeProbe: RouteProbe): string[] {
    const out: string[] = [];
    const seen: Set<string> = new Set<string>();
    let answered: number = 0;
    for (const f of items) {
      if (!f.bundleName || seen.has(f.bundleName)) continue;
      seen.add(f.bundleName);
      let state: boolean | undefined = undefined;
      try {
        state = presence.installed(f.bundleName);
      } catch (_err) {
        state = undefined;
      }
      if (state === undefined) continue;
      answered += 1;
      if (state) out.push(f.bundleName);
    }
    // presence 一条结论都没给出 → 系统不让三方应用查安装态，退回链接探测。
    if (answered === 0) return InstalledProbe.detectedBundles(items, routeProbe);
    return out.sort();
  }
}

export default InstalledProbe;
