import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
import type { UsageRecorder } from '../launch/LaunchResult';

/**
 * 用量快照（产品 Spec §6.2 / IOS_RANKING_SPEC）。
 * 五个只读方法供 RankingEngine 消费；不含 isPinned（B1：收藏移出第一期）。
 * sceneAffinity 是公式保留项，但首版无场景传感器，UsageSnapshot 不暴露它，
 * RankingEngine 内部按常量 0 处理（见 ios-aligned-design.md §2）。
 */
export interface UsageSnapshot {
  dayCount(id: string, now: number): number;
  monthCount(id: string, now: number): number;
  hourAffinity(id: string, hour: number): number;
  lastUsedAt(id: string): number;
  recentSequence(): string[];
}

interface UsageEvent {
  functionId: string;
  timestamp: number;
}

const STORE_NAME: string = 'atomic_function_usage';
const EVENTS_KEY: string = 'events';
const WINDOW_MS: number = 30 * 24 * 3600 * 1000; // 保留约一个月的滚动记录
const DAY_MS: number = 24 * 3600 * 1000;

/**
 * 用量记录存储。D4 拍板：用量不可见、不可清空——本类不提供任何查询全部
 * 记录/清空/重置的公开方法，只暴露 UsageSnapshot 五个排序输入与 record()。
 *
 * 实现分两层：
 *  - 进程内 `events` 是权威数据（纯逻辑，可被本地单测直接驱动）；
 *  - 可选注入的 `Preferences` 仅作跨进程持久化（卡片/UIAbility 分属不同进程时
 *    通过 loadFromPreferences 恢复），不持久化不影响纯逻辑正确性。
 *
 * 不引入 @State、不引入用户侧 UI；用量只作为排序内部输入。
 */
/**
 * 直接用 SDK 的真实类型，而非自造同形 interface：ArkTS 禁止结构类型
 * （arkts-no-structural-typing），自造的 PrefHandle 无法接收 preferences.Preferences。
 * getSync 返回 ValueType（number|string|...），故取值处需 typeof 收窄。
 */
type PrefHandle = preferences.Preferences;

export class UsageStore implements UsageSnapshot, UsageRecorder {
  private events: UsageEvent[] = [];
  private pref: PrefHandle | undefined = undefined;

  /** 从同步 Preferences 句柄恢复（跨进程/冷启动）。生产侧 FormAbility/UIAbility 调用。 */
  static withPreferencesSync(pref: PrefHandle): UsageStore {
    const store = new UsageStore();
    store.attachPreferencesSync(pref);
    return store;
  }

  /** 注入持久化句柄并恢复已有记录。I3：卡片与 UIAbility 分属进程，靠它共享用量。 */
  attachPreferencesSync(pref: PrefHandle): void {
    this.pref = pref;
    try {
      const raw = pref.getSync(EVENTS_KEY, '[]');
      const parsed: UsageEvent[] = typeof raw === 'string' ? JSON.parse(raw) as UsageEvent[] : [];
      if (Array.isArray(parsed)) {
        this.events = parsed.filter((e) => e && typeof e.functionId === 'string' && typeof e.timestamp === 'number');
      }
    } catch (_err) {
      this.events = [];
    }
  }

  /** 保留异步门面（生产可用 getPreferences(context, STORE_NAME) 得到句柄后转发）。 */
  static async withPreferences(context: common.Context): Promise<UsageStore> {
    const store = new UsageStore();
    try {
      const pref = await preferences.getPreferences(context, STORE_NAME);
      const raw = await pref.get(EVENTS_KEY, '[]');
      const parsed: UsageEvent[] = typeof raw === 'string' ? JSON.parse(raw) as UsageEvent[] : [];
      if (Array.isArray(parsed)) {
        store.events = parsed.filter((e) => e && typeof e.functionId === 'string' && typeof e.timestamp === 'number');
      }
    } catch (_err) {
      store.events = [];
    }
    return store;
  }

  /** 追加一条使用记录并**写回**持久化（I3）；D4：只写，不暴露查看/清空入口。 */
  async record(functionId: string, at: number): Promise<void> {
    this.events.push({ functionId: functionId, timestamp: at });
    // 滚动裁剪：丢弃 30 天前的记录，控制体积。
    const cutoff = at - WINDOW_MS;
    this.events = this.events.filter((e) => e.timestamp >= cutoff);
    if (this.pref) {
      try {
        this.pref.putSync(EVENTS_KEY, JSON.stringify(this.events));
        this.pref.flushSync();
      } catch (_err) {
        // 持久化失败不影响内存排序正确性（纯逻辑仍可用）。
      }
    }
  }

  dayCount(id: string, now: number): number {
    const start = now - DAY_MS;
    let c = 0;
    for (const e of this.events) {
      if (e.functionId === id && e.timestamp >= start && e.timestamp <= now) c++;
    }
    return c;
  }

  monthCount(id: string, now: number): number {
    const start = now - WINDOW_MS;
    let c = 0;
    for (const e of this.events) {
      if (e.functionId === id && e.timestamp >= start && e.timestamp <= now) c++;
    }
    return c;
  }

  /** 时段亲和：该函数在给定小时的用量 / 该函数总用量，clamp [0,1]。无记录为 0。 */
  hourAffinity(id: string, hour: number): number {
    let total = 0;
    let inHour = 0;
    for (const e of this.events) {
      if (e.functionId !== id) continue;
      total++;
      if (new Date(e.timestamp).getHours() === hour) inHour++;
    }
    return total === 0 ? 0 : inHour / total;
  }

  lastUsedAt(id: string): number {
    let last = 0;
    for (const e of this.events) {
      if (e.functionId === id && e.timestamp > last) last = e.timestamp;
    }
    return last;
  }

  /** 最近使用序列（按时间升序），供 seqBoost 使用。 */
  recentSequence(): string[] {
    const sorted = this.events.slice().sort((a, b) => a.timestamp - b.timestamp);
    return sorted.map((e) => e.functionId);
  }
}

export default UsageStore;
