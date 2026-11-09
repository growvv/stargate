import { CATEGORIES } from '../main/ets/model/AtomicFunction';
import type { Route, AtomicFunction } from '../main/ets/model/AtomicFunction';
import type { UsageSnapshot } from '../main/ets/data/UsageStore';
import { CapabilityRepository } from '../main/ets/data/CapabilityRepository';

/**
 * 供 Task 2–6 共享的纯内存夹具。
 * makeItems 用合成条目做单测，**不冒充真实能力库**（A3：真实条目只收 Task 5 实测可用者）。
 */

/** 12 个互不相同的可读 App 名；'支付宝' 只在 index 0 出现一次（SearchFilter 断言用）。 */
const APP_NAMES: string[] = [
  '支付宝', '微信', '高德地图', '百度地图', '美团', '淘宝',
  '抖音', '京东', '携程', '哔哩哔哩', '12306', '网易云音乐'
];

/** 12 个互不相同、且互不为子串的功能名（SearchFilter 断言用）。 */
const LABELS: string[] = [
  '付款码', '扫一扫', '路线规划', '公交查询', '外卖订单', '购物车',
  '短视频', '收货地址', '火车票', '视频播放', '车票查询', '音乐播放'
];

/** 返回一个上午 08:30 的确定时间戳（本地时区，getHours() === 8）。 */
export function nowMorning(): number {
  return new Date(2026, 10, 7, 8, 30, 0).getTime();
}

/** 由单条 Route 造一个 AtomicFunction（含 appName，单路由，无 home）。 */
export function makeFunction(route: Route): AtomicFunction {
  return {
    id: 'fixture-fn',
    label: '付款码',
    appName: '支付宝',
    bundleName: 'com.stargate.demo',
    category: CATEGORIES[0],
    route: route,
    source: 'shortcut',
    confidence: 1.0
  };
}

/** 造 n 条合成条目：id='fn-0'..'fn-n-1'，9 类目循环，首条 appName='支付宝'。 */
export function makeItems(n: number): AtomicFunction[] {
  const out: AtomicFunction[] = [];
  for (let i = 0; i < n; i++) {
    const appName = i === 0
      ? '支付宝'
      : APP_NAMES[1 + (i - 1) % (APP_NAMES.length - 1)];
    out.push({
      id: 'fn-' + i,
      label: LABELS[i % LABELS.length],
      appName: appName,
      bundleName: 'com.stargate.demo.' + i,
      category: CATEGORIES[i % CATEGORIES.length],
      route: { kind: 'deeplink', uri: 'stargate://fn/' + i },
      source: 'shortcut',
      confidence: 1.0
    });
  }
  return out;
}

/** 可覆盖任意方法的 UsageSnapshot 假实现；默认全零/空序列（冷启动）。 */
export function fakeUsage(overrides?: Partial<UsageSnapshot>): UsageSnapshot {
  const base: UsageSnapshot = {
    dayCount: (_id: string, _now: number) => 0,
    monthCount: (_id: string, _now: number) => 0,
    hourAffinity: (_id: string, _hour: number) => 0,
    lastUsedAt: (_id: string) => 0,
    recentSequence: () => []
  };
  return {
    dayCount: overrides?.dayCount ?? base.dayCount,
    monthCount: overrides?.monthCount ?? base.monthCount,
    hourAffinity: overrides?.hourAffinity ?? base.hourAffinity,
    lastUsedAt: overrides?.lastUsedAt ?? base.lastUsedAt,
    recentSequence: overrides?.recentSequence ?? base.recentSequence
  };
}

/** 内存能力库；n=0 表示空库。get() 返回与 listAll() 相同的对象引用。 */
export function makeCatalog(n: number): CapabilityRepository {
  return CapabilityRepository.fromItems(makeItems(n));
}
