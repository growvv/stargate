import type { AtomicFunction } from '../model/AtomicFunction';
import type { UsageSnapshot } from '../data/UsageStore';
import { CapabilityRepository } from '../data/CapabilityRepository';
import { CategoryOrder } from '../data/CategoryOrder';
import { RankingEngine } from '../recommend/RankingEngine';

/** 卡片视图数据（产品 Spec §2.2）。 */
export interface CategoryChip {
  name: string;
  count: number;
}

export interface CardViewData {
  suggestions: AtomicFunction[];
  categories: CategoryChip[];
  contextHint: string;
  isEmpty: boolean;
}

const MAX_SUGGESTIONS: number = 8;

/** 按时段生成情境提示（冷启动先验也走 RankingEngine 的 hourAffinity）。 */
function hintForHour(hour: number): string {
  if (hour < 6) return '夜深了 · 常用功能在这里';
  if (hour < 11) return '上午好 · 通勤推荐打车';
  if (hour < 14) return '午间好 · 付款与生活';
  if (hour < 18) return '下午好 · 高频功能直达';
  return '晚上好 · 购物与娱乐';
}

/** 纯组装：给定已取出的条目，产出 CardViewData（同步/异步共用）。 */
function compose(all: AtomicFunction[], usage: UsageSnapshot, now: number,
  categoryOrder?: string[]): CardViewData {
  // 用户拍板（2026-11-09）：卡片推荐位优先真实 App 功能，让每个图标都能显示
  // App 自己的 logo。「系统能力·选应用」这类垂直入口（route.kind === 'vertical'）
  // 没有 App logo，冷启动时却因 confidence 更高挤满 2×2 推荐框，只剩相同符号；
  // 这里把它们放到后备，只有 App 条目不足时才补位（不丢功能、不造假数据）。
  const ranked = RankingEngine.topN(all, usage, now, all.length);
  const appFirst: AtomicFunction[] = [];
  const pickers: AtomicFunction[] = [];
  for (const f of ranked) {
    if (f.route.kind === 'vertical') pickers.push(f); else appFirst.push(f);
  }
  const suggestions: AtomicFunction[] = [];
  for (const f of appFirst) {
    if (suggestions.length >= MAX_SUGGESTIONS) break;
    suggestions.push(f);
  }
  for (const f of pickers) {
    if (suggestions.length >= MAX_SUGGESTIONS) break;
    suggestions.push(f);
  }

  // 类目顺序：用户可在配置页拖动排序（持久化在 CategoryOrderStore）。
  // 只展示有内容的类目；未配置时退回系统默认顺序。
  const order: string[] = CategoryOrder.normalize(categoryOrder ?? []);
  const counts: Record<string, number> = {};
  for (const f of all) {
    counts[f.category] = (counts[f.category] ?? 0) + 1;
  }
  const categories: CategoryChip[] = [];
  for (const name of order) {
    const c = counts[name] ?? 0;
    if (c > 0) categories.push({ name: name, count: c });
  }

  const hour = new Date(now).getHours();
  return {
    suggestions: suggestions,
    categories: categories,
    contextHint: hintForHour(hour),
    isEmpty: all.length === 0
  };
}

export class WidgetCardData {
  /**
   * 异步组装：repo.listAll() 走真实能力库（D5 外部文件 / rawfile 种子）。
   * 建议区最多 8 格（B2′：不足按实际、不凑数）；空库 → isEmpty=true + suggestions=[] 引导态。
   */
  static async build(repo: CapabilityRepository, usage: UsageSnapshot, now: number,
    categoryOrder?: string[]): Promise<CardViewData> {
    const all = await repo.listAll();
    return compose(all, usage, now, categoryOrder);
  }

  /**
   * 同步组装：卡片 onAddForm / onUpdateForm 是同步回调，无法 await。
   * 传入的 repo 应为已注入条目（如 CapabilityRepository.fromItems(...)），不触碰异步 SDK。
   */
  static buildSync(repo: CapabilityRepository, usage: UsageSnapshot, now: number,
    categoryOrder?: string[]): CardViewData {
    return compose(repo.itemsSnapshot(), usage, now, categoryOrder);
  }
}

export default WidgetCardData;
