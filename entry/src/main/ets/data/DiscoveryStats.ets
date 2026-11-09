/**
 * Read-only summary of the shipped declaration scan.  These numbers describe
 * candidates, not launchable functions: discovery evidence stays separate from
 * capabilities.json until an L0/L5 page observation is reviewed.
 */
export interface DiscoveryStatsValue {
  bundleCount: number;
  schemes: number;
  linkFeatures: number;
  shortcuts: number;
  withoutHints: number;
  verifiedCatalogItems: number;
  runtimeCases: number;
  runtimeCandidates: number;
  runtimeConfirmed: number;
}

export class DiscoveryStats {
  static current(): DiscoveryStatsValue {
    return {
      bundleCount: 48,
      schemes: 37,
      linkFeatures: 22,
      shortcuts: 17,
      withoutHints: 11,
      verifiedCatalogItems: 4,
      runtimeCases: 87,
      runtimeCandidates: 67,
      runtimeConfirmed: 4
    };
  }

  static headline(): string {
    const s = DiscoveryStats.current();
    return '声明扫描 ' + s.bundleCount + ' 个 App · ' + s.schemes + ' schemes · ' +
      s.linkFeatures + ' linkFeatures · ' + s.shortcuts + ' shortcuts · 已探测 ' +
      s.runtimeCandidates + ' 个候选';
  }

  static boundary(): string {
    const s = DiscoveryStats.current();
    return '当前可直接使用 ' + s.verifiedCatalogItems + ' 项；运行时确认 ' +
      s.runtimeConfirmed + ' 条；' + s.withoutHints +
      ' 个 App 没有公开入口线索，需 REA / 受控 UI Test 继续分析';
  }
}

export default DiscoveryStats;
