import { describe, it, expect } from '@ohos/hypium';
import { UsageStore } from '../main/ets/data/UsageStore';

/** 内存版 Preferences 替身：验证 record() 真的写回并 flush，而不只是改内存数组。 */
function mockPref() {
  const saved: Record<string, string> = {};
  return {
    saved: saved,
    getSync: (_k: string, d: string) => (_k in saved ? saved[_k] : d),
    putSync: (k: string, v: string) => { saved[k] = v; },
    flushSync: () => {},
  };
}

export default function usageStoreTest() {
  describe('UsageStore', () => {
    it('usage_store_updates_snapshot_after_record', 0, async () => {
      const store = new UsageStore();
      // 冷启动：无任何记录，五个快照方法应给出中性/空值，不抛异常。
      expect(store.dayCount('fn-0', 0)).assertEqual(0);
      expect(store.monthCount('fn-0', 0)).assertEqual(0);
      expect(store.lastUsedAt('fn-0')).assertEqual(0);
      expect(store.recentSequence().length).assertEqual(0);

      const t = 1700000000000;
      await store.record('fn-0', t);
      await store.record('fn-0', t + 1000);
      await store.record('fn-1', t + 2000);

      // 传入 now=t+3000，三条记录都落在同一"日/月"窗口内。
      const now = t + 3000;
      expect(store.dayCount('fn-0', now)).assertEqual(2);
      expect(store.monthCount('fn-0', now)).assertEqual(2);
      expect(store.dayCount('fn-1', now)).assertEqual(1);
      expect(store.dayCount('missing', now)).assertEqual(0);
      expect(store.lastUsedAt('fn-0')).assertEqual(t + 1000);
      expect(store.recentSequence().length).assertEqual(3);
      expect(store.recentSequence()[2]).assertEqual('fn-1');
      // hourAffinity 在 [0,1]，对该小时有记录应 > 0。
      const h = new Date(t).getHours();
      expect(store.hourAffinity('fn-0', h) > 0).assertTrue();
      expect(store.hourAffinity('missing', h) >= 0).assertTrue();
    });
    it('record_persists_via_sync_preferences_and_reloads', 0, async () => {
      // I3：用量必须跨进程持久化；withPreferencesSync 从同一 Preferences 恢复。
      const pref = mockPref();
      const store = new UsageStore();
      store.attachPreferencesSync(pref);
      const t = 1700000000000;
      await store.record('fn-9', t);
      // 写回的字符串应包含该条记录（不是只改内存）。
      expect(pref.saved['events'].indexOf('fn-9') >= 0).assertTrue();
      const restored = UsageStore.withPreferencesSync(pref);
      expect(restored.dayCount('fn-9', t + 1000)).assertEqual(1);
      expect(restored.recentSequence()[0]).assertEqual('fn-9');
    });
  });
}
