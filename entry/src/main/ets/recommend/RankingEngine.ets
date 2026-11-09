import type { AtomicFunction } from '../model/AtomicFunction';
import type { UsageSnapshot } from '../data/UsageStore';

/**
 * IOS_RANKING_SPEC 定稿公式（产品 Spec §6.2 / ios-aligned-design.md §2）：
 *
 *   score(f, now) =
 *       0.30 * norm(dayCount)   + 0.20 * norm(monthCount)
 *     + 0.18 * exp(-Δt / τ)      // τ = 36h；无历史按 0
 *     + 0.12 * hourAffinity      // 冷启动时段先验也走这里
 *     + 0.08 * sceneAffinity     // 首版无场景传感器 → 常量 0
 *     + 0.07 * seqBoost          // 出现在最近序列中给 1
 *     + 0.05 * confidence        // clamp [0,1]
 *
 * 打散：同一 category 最多 2 条；不足 n 返回实际条数、绝不补位（B2′）。
 * 同分按 id 字典序，保证可复现。无 isPinned / pinnedBoost / 收藏因子（B1）。
 *
 * ArkTS 约束（arkts-no-untyped-obj-literals）：对象字面量必须有显式声明的
 * interface/class 上下文类型，故中间结果用下面两个 interface + 显式类型数组。
 */
const TAU_MS: number = 36 * 3600 * 1000;
const W_DAY: number = 0.30;
const W_MONTH: number = 0.20;
const W_DECAY: number = 0.18;
const W_HOUR: number = 0.12;
const W_SCENE: number = 0.08;
const W_SEQ: number = 0.07;
const W_CONF: number = 0.05;
const MAX_PER_CATEGORY: number = 2;

interface CandidateFactors {
  f: AtomicFunction;
  day: number;
  month: number;
  last: number;
  hourAff: number;
}

interface ScoredCandidate {
  f: AtomicFunction;
  score: number;
}

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

/**
 * 冷启动时段先验（IOS_RANKING_SPEC R3 / I4）：无任何用量历史时，按当前小时给
 * 9 类目一个 0..1 的先验分，注入 W_HOUR * hourAffinity 项（不新增权重、不改公式）。
 * 上午偏 出行/支付/工具效率，晚间偏 购物/娱乐/生活；与 WidgetCardData.hintForHour 一致。
 */
const MORNING_CATEGORIES: string[] = ['出行', '支付', '工具效率', '健康运动'];
const EVENING_CATEGORIES: string[] = ['购物', '娱乐', '生活', '社交'];
function coldStartHourPrior(category: string, hour: number): number {
  if (hour < 11) {
    return MORNING_CATEGORIES.indexOf(category) >= 0 ? 0.9 : 0.2;
  }
  if (hour >= 18) {
    return EVENING_CATEGORIES.indexOf(category) >= 0 ? 0.9 : 0.2;
  }
  return 0.5; // 午后中性，保持确定性
}

export class RankingEngine {
  static topN(items: AtomicFunction[], usage: UsageSnapshot, now: number, n: number): AtomicFunction[] {
    if (!items || items.length === 0 || n <= 0) return [];

    const hour: number = new Date(now).getHours();
    const seq: string[] = usage.recentSequence() ?? [];
    const seqSet = new Set<string>(seq);

    // 预计算每个候选的原始因子（供 norm 相对候选集归一化）。
    const raw: CandidateFactors[] = [];
    for (const f of items) {
      raw.push({
        f: f,
        day: usage.dayCount(f.id, now),
        month: usage.monthCount(f.id, now),
        last: usage.lastUsedAt(f.id),
        hourAff: usage.hourAffinity(f.id, hour)
      });
    }
    let maxDay = 0;
    let maxMonth = 0;
    let hasHistory = false;
    for (const r of raw) {
      if (r.day > maxDay) maxDay = r.day;
      if (r.month > maxMonth) maxMonth = r.month;
      if (r.day > 0 || r.month > 0 || r.last > 0) hasHistory = true;
    }

    const scored: ScoredCandidate[] = [];
    for (const r of raw) {
      const normDay = maxDay === 0 ? 0 : r.day / maxDay;
      const normMonth = maxMonth === 0 ? 0 : r.month / maxMonth;
      const decay = r.last === 0 ? 0 : Math.exp(-Math.max(0, now - r.last) / TAU_MS);
      const scene = 0; // 首版常量 0，保留接口
      const seqBoost = seqSet.has(r.f.id) ? 1 : 0;
      const conf = clamp01(r.f.confidence);
      // I4：冷启动（全库无用量）用时段先验替代恒为 0 的 hourAffinity；有历史则用真实值。
      const hourAff = hasHistory ? clamp01(r.hourAff) : coldStartHourPrior(r.f.category, hour);
      const score =
          W_DAY * normDay + W_MONTH * normMonth + W_DECAY * decay +
          W_HOUR * hourAff + W_SCENE * scene + W_SEQ * seqBoost + W_CONF * conf;
      scored.push({ f: r.f, score: score });
    }

    // 分数降序；同分按 id 字典序，保证可复现。
    scored.sort((a: ScoredCandidate, b: ScoredCandidate) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.f.id < b.f.id ? -1 : (a.f.id > b.f.id ? 1 : 0);
    });

    // 类目打散：任一 category 最多 MAX_PER_CATEGORY 条；不足 n 不补位。
    const out: AtomicFunction[] = [];
    const perCategory: Record<string, number> = {};
    for (const s of scored) {
      if (out.length >= n) break;
      const c = s.f.category;
      const used = perCategory[c] ?? 0;
      if (used >= MAX_PER_CATEGORY) continue;
      perCategory[c] = used + 1;
      out.push(s.f);
    }
    return out; // 绝不补位：候选不足时返回实际条数
  }
}

export default RankingEngine;
