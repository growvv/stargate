import { describe, it, expect } from '@ohos/hypium';
import { RecentAdditions } from '../main/ets/recommend/RecentAdditions';
import { makeItems } from './TestFixtures';

export default function recentAdditionsTest() {
  describe('RecentAdditions', () => {
    it('defaults_to_newest_catalog_entries_when_no_install_history', 0, () => {
      // 首次运行没有安装时间差：用目录尾部（最新加入）的条目作为默认填充。
      const items = makeItems(6);
      const picked = RecentAdditions.select(items, undefined, 4);
      expect(picked.length).assertEqual(4);
      expect(picked.map((f) => f.id).join(',')).assertEqual('fn-5,fn-4,fn-3,fn-2');
    });
    it('recently_detected_app_ranks_before_default_fill', 0, () => {
      // 用户新装了 fn-1 对应的 App（时间戳 100），它要替换掉默认填充的第一格。
      const items = makeItems(6);
      const seen = {};
      seen[items[1].bundleName] = 100;
      const picked = RecentAdditions.select(items, seen, 4);
      expect(picked[0].id).assertEqual('fn-1');
      expect(picked.length).assertEqual(4);
      // 其余仍是目录尾部，且不与新 App 重复。
      expect(picked.map((f) => f.id).join(',')).assertEqual('fn-1,fn-5,fn-4,fn-3');
    });
    it('only_one_slot_per_app', 0, () => {
      const items = makeItems(6);
      items[4].bundleName = items[5].bundleName; // 同一 App 的两个功能
      const picked = RecentAdditions.select(items, undefined, 4);
      const bundles = picked.map((f) => f.bundleName);
      expect(new Set(bundles).size).assertEqual(bundles.length);
      expect(picked.length).assertEqual(4);
    });
    it('skips_system_vertical_entries_without_an_app', 0, () => {
      const items = makeItems(4);
      items[3].route = { kind: 'vertical', uri: 'vertical://x' };
      const picked = RecentAdditions.select(items, undefined, 4);
      expect(picked.length).assertEqual(3);
      expect(picked.filter((f) => f.route.kind === 'vertical').length).assertEqual(0);
    });
    it('merge_seen_baselines_first_run_then_marks_new_installs', 0, () => {
      const first = RecentAdditions.mergeSeen(undefined, ['a', 'b'], 1000, true);
      expect(first['a']).assertEqual(0);
      expect(first['b']).assertEqual(0);
      const next = RecentAdditions.mergeSeen(first, ['a', 'b', 'c'], 2000, false);
      expect(next['a']).assertEqual(0);
      expect(next['c']).assertEqual(2000);
      expect(RecentAdditions.isRecentlyAdded(next, 'c')).assertTrue();
      expect(RecentAdditions.isRecentlyAdded(next, 'a')).assertFalse();
      // 卸载的 App 从表里移除。
      const removed = RecentAdditions.mergeSeen(next, ['b', 'c'], 3000, false);
      expect(removed['a'] === undefined).assertTrue();
      expect(removed['c']).assertEqual(2000);
    });
  });
}
