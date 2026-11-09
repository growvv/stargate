import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 「最近添加」（2026-11-09 用户拍板，替换「最近打开」）。
 *
 * 定义：用户最近安装/新检测到的 App 里，我们能力库能覆盖到的功能。
 *  - 每个 App 只占一格（同一 App 的多个功能不重复占满 2×2 框）；
 *  - 系统「选应用」垂直入口（route.kind === 'vertical'）没有 App 归属，不参与；
 *  - 没有新 App 时，用目录里**最新加入的条目**（数组尾部）作为默认填充；
 *    以后检测到新安装的 App，其时间戳更大，自动排到前面并替换默认填充。
 *
 * 纯逻辑，可被 Node 单测直接驱动；时间戳表由 InstallSnapshot 持久化。
 */
export type BundleFirstSeen = Record<string, number>;

interface IndexedItem {
  f: AtomicFunction;
  index: number;
}

export class RecentAdditions {
  static select(items: AtomicFunction[], firstSeen: BundleFirstSeen | undefined, n: number): AtomicFunction[] {
    if (!items || items.length === 0 || n <= 0) return [];
    const decorated: IndexedItem[] = [];
    for (let i = 0; i < items.length; i++) decorated.push({ f: items[i], index: i });
    decorated.sort((a: IndexedItem, b: IndexedItem) => {
      const sa: number = firstSeen ? (firstSeen[a.f.bundleName] ?? 0) : 0;
      const sb: number = firstSeen ? (firstSeen[b.f.bundleName] ?? 0) : 0;
      if (sb !== sa) return sb - sa;
      // 同一时间戳（或都无时间戳）时，目录尾部视为更新。
      if (b.index !== a.index) return b.index - a.index;
      return a.f.id < b.f.id ? -1 : (a.f.id > b.f.id ? 1 : 0);
    });
    const out: AtomicFunction[] = [];
    const seenBundles: Set<string> = new Set<string>();
    for (const d of decorated) {
      if (out.length >= n) break;
      if (d.f.route.kind === 'vertical') continue;
      if (seenBundles.has(d.f.bundleName)) continue;
      seenBundles.add(d.f.bundleName);
      out.push(d.f);
    }
    return out;
  }

  /**
   * 把本次检测到的已安装 App 合并进「首次见到」表。
   *  - firstRun：首次建立基线，全部记 0 —— 它们不算「最近添加」，
   *    最近添加的默认填充由目录尾部条目承担；
   *  - 之后：已存在的保留原时间；新出现的记 now（用户新装了 App）；
   *  - 本次未检测到的 App 从表里移除（卸载后重装会重新记 now）。
   */
  static mergeSeen(prev: BundleFirstSeen | undefined, detectedBundles: string[],
    now: number, firstRun: boolean): BundleFirstSeen {
    const out: BundleFirstSeen = {};
    for (const bundle of detectedBundles) {
      const old: number | undefined = prev ? prev[bundle] : undefined;
      out[bundle] = firstRun ? 0 : (old === undefined ? now : old);
    }
    return out;
  }

  /** 该 App 是否在基线之后被新检测到（时间戳 > 0）。 */
  static isRecentlyAdded(firstSeen: BundleFirstSeen | undefined, bundleName: string): boolean {
    if (!firstSeen) return false;
    return (firstSeen[bundleName] ?? 0) > 0;
  }
}

export default RecentAdditions;
