export interface InstallSnapshot {
  installedIds: string[];
  probedAt: number;
  appVersionFingerprint: string;
  /** Positive = consecutive true observations; negative = consecutive false. */
  streak: Record<string, number>;
  /**
   * 「最近添加」时间戳（bundleName → 首次检测到已安装的时刻）。
   * 首次建立基线时全部为 0（不算最近添加）；之后新检测到的 App 记 now。
   */
  bundleFirstSeen: Record<string, number>;
  /** 上次扫描 L1 条目所属 App 安装状态的时间（0 = 尚未扫描）。 */
  bundlesProbedAt: number;
}

function emptySeen(): Record<string, number> {
  // ArkTS 拒绝把 `{}` 直接赋给 Record 类型，用 JSON 往返生成空表。
  return JSON.parse('{}') as Record<string, number>;
}

export interface CatalogDiffResult {
  added: string[];
  removed: string[];
  unchanged: string[];
}

export class CatalogDiff {
  static empty(): InstallSnapshot {
    return {
      installedIds: [], probedAt: 0, appVersionFingerprint: '', streak: {},
      bundleFirstSeen: emptySeen(), bundlesProbedAt: 0
    };
  }

  static diff(prev: string[], next: string[]): CatalogDiffResult {
    const p = new Set<string>(prev);
    const n = new Set<string>(next);
    const all = Array.from(new Set<string>(prev.concat(next))).sort();
    const added: string[] = [];
    const removed: string[] = [];
    const unchanged: string[] = [];
    all.forEach((id) => {
      if (n.has(id) && !p.has(id)) added.push(id);
      else if (p.has(id) && !n.has(id)) removed.push(id);
      else unchanged.push(id);
    });
    return { added, removed, unchanged };
  }

  static confirm(prev: InstallSnapshot, probed: string[], allIds: string[], now: number): InstallSnapshot {
    const probedSet = new Set<string>(probed);
    const confirmed: string[] = [];
    const streak: Record<string, number> = {};
    const oldInstalled = new Set<string>(prev.installedIds);
    allIds.slice().sort().forEach((id) => {
      const current = probedSet.has(id);
      const old = prev.streak[id] ?? 0;
      const value = current ? (old > 0 ? old + 1 : 1) : (old < 0 ? old - 1 : -1);
      streak[id] = value;
      const isInstalled = value >= 2 ? true : value <= -2 ? false : oldInstalled.has(id);
      if (isInstalled) confirmed.push(id);
    });
    return {
      installedIds: confirmed,
      probedAt: now,
      appVersionFingerprint: prev.appVersionFingerprint,
      streak,
      bundleFirstSeen: prev.bundleFirstSeen ?? emptySeen(),
      bundlesProbedAt: prev.bundlesProbedAt ?? 0
    };
  }

  static resetDebounce(prev: InstallSnapshot): InstallSnapshot {
    const streak: Record<string, number> = {};
    return {
      installedIds: prev.installedIds.slice(),
      probedAt: prev.probedAt,
      appVersionFingerprint: prev.appVersionFingerprint,
      streak,
      bundleFirstSeen: prev.bundleFirstSeen ?? emptySeen(),
      bundlesProbedAt: prev.bundlesProbedAt ?? 0
    };
  }
}

export default CatalogDiff;
