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

export class BundleSchemeProbe implements SchemeProbe, RouteProbe {
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
    const uri: string = route.uri ?? '';
    if (!uri) return false;
    try {
      return bundleManager.canOpenLink(uri);
    } catch (_err) {
      return false;
    }
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
}

export default InstalledProbe;
