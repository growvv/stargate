import type common from '@ohos.app.ability.common';
import { CapabilityRepository } from './CapabilityRepository';

/**
 * A declaration discovered from an installed app.  This is deliberately not
 * an AtomicFunction: a scheme, shortcut or linkFeature only proves that an
 * entry was declared, never that it lands on a usable atomic page.
 */
export interface DiscoveryCandidate {
  id: string;
  bundleName: string;
  appName: string;
  category: string;
  status: string;
  sourceLayer: string;
  schemes: string[];
  linkFeatures: string[];
  shortcuts: string[];
  pathHints: string[];
  entrypointCount: number;
  productionEligible: boolean;
  evidencePath: string;
}

interface DiscoveryCandidateSeed {
  schemaVersion: string;
  generatedAt: string;
  records: DiscoveryCandidate[];
}

/** Read-only loader for the generated discovery ledger projection. */
export class DiscoveryCandidateCatalog {
  static parse(text: string): DiscoveryCandidate[] {
    if (!text) return [];
    try {
      const seed = JSON.parse(text) as DiscoveryCandidateSeed;
      if (!seed || !Array.isArray(seed.records)) return [];
      return seed.records.filter((r: DiscoveryCandidate) => r && r.id && r.bundleName && r.appName)
        .map((r: DiscoveryCandidate): DiscoveryCandidate => {
          // ArkTS 禁止无上下文的匿名对象字面量（arkts-no-untyped-obj-literals），
          // 显式声明局部变量后再返回。
          const record: DiscoveryCandidate = {
            id: r.id,
            bundleName: r.bundleName,
            appName: r.appName,
            category: r.category || '其他',
            status: r.status || 'unknown',
            sourceLayer: r.sourceLayer || 'unknown',
            schemes: Array.isArray(r.schemes) ? r.schemes.slice() : [],
            linkFeatures: Array.isArray(r.linkFeatures) ? r.linkFeatures.slice() : [],
            shortcuts: Array.isArray(r.shortcuts) ? r.shortcuts.slice() : [],
            pathHints: Array.isArray(r.pathHints) ? r.pathHints.slice() : [],
            entrypointCount: typeof r.entrypointCount === 'number' ? r.entrypointCount : 0,
            productionEligible: r.productionEligible === true,
            evidencePath: r.evidencePath || 'probe/discovery-ledger.json'
          };
          return record;
        });
    } catch (_err) {
      return [];
    }
  }

  static fromContextSync(context: common.Context): DiscoveryCandidate[] {
    try {
      const bytes = context.resourceManager.getRawFileContentSync('discovery-candidates.json');
      return DiscoveryCandidateCatalog.parse(CapabilityRepository.decodeUtf8(bytes));
    } catch (_err) {
      return [];
    }
  }

  static statusLabel(status: string): string {
    if (status === 'declared') return '已声明，待验证';
    if (status === 'reverse_candidate') return 'REA 候选';
    if (status === 'runtime_observed') return '运行时已观察';
    if (status === 'rejected') return '已拒绝';
    return '暂无公开线索';
  }

  static sourceLabel(sourceLayer: string): string {
    if (sourceLayer === 'L1-L2') return 'Shortcut / Link / Scheme';
    if (sourceLayer === 'L4') return 'REA 静态分析';
    if (sourceLayer === 'L5') return '运行时观察';
    return '声明未发现入口提示';
  }

  static filter(records: DiscoveryCandidate[], query: string): DiscoveryCandidate[] {
    const q = (query || '').trim().toLowerCase();
    if (!q) return records.slice();
    return records.filter((r: DiscoveryCandidate) => {
      const haystack = [r.appName, r.bundleName, r.category, r.status, r.sourceLayer]
        .concat(r.schemes, r.linkFeatures, r.shortcuts, r.pathHints)
        .join(' ').toLowerCase();
      return haystack.indexOf(q) >= 0;
    });
  }

  static hintPreview(candidate: DiscoveryCandidate): string {
    const hints: string[] = [];
    candidate.schemes.slice(0, 2).forEach((s: string) => hints.push(s + '://'));
    candidate.linkFeatures.slice(0, 2).forEach((s: string) => hints.push(s));
    candidate.shortcuts.slice(0, 2).forEach((s: string) => hints.push('shortcut:' + s));
    if (hints.length === 0 && candidate.pathHints.length > 0) hints.push(candidate.pathHints[0]);
    if (hints.length === 0) return '未发现 scheme / linkFeature / shortcut';
    return hints.join(' · ') + (candidate.entrypointCount > hints.length ? ' · …' : '');
  }
}

export default DiscoveryCandidateCatalog;
