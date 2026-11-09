import { describe, it, expect } from '@ohos/hypium';
import { RankingEngine } from '../main/ets/recommend/RankingEngine';
import { makeItems, nowMorning, fakeUsage } from './TestFixtures';

export default function rankingTest() {
  describe('RankingEngine', () => {
    it('cold_start_fills_up_to_eight_slots_without_crash', 0, () => {
      const items = makeItems(12);
      const top = RankingEngine.topN(items, fakeUsage(), nowMorning(), 8);
      expect(top.length).assertEqual(8);
      expect(new Set(top.map(i => i.category)).size > 1).assertTrue();
    });
    it('small_catalog_returns_actual_count_not_padded', 0, () => {
      // B2′：首版能力库只收少量已验证条目，不足 8 格按实际数量显示，不凑数
      const items = makeItems(3);
      const top = RankingEngine.topN(items, fakeUsage(), nowMorning(), 8);
      expect(top.length).assertEqual(3);
    });
    it('empty_catalog_returns_zero', 0, () => {
      const top = RankingEngine.topN(makeItems(0), fakeUsage(), nowMorning(), 8);
      expect(top.length).assertEqual(0);
    });
    it('cold_start_hour_prior_changes_category_order', 0, () => {
      // I4：无用量历史时，上午（通勤/出行）与晚上（购物/娱乐）冷启动排序应不同。
      const items = makeItems(12);
      const morning = new Date(2026, 10, 7, 8, 30, 0).getTime();
      const evening = new Date(2026, 10, 7, 21, 30, 0).getTime();
      const am = RankingEngine.topN(items, fakeUsage(), morning, 4);
      const pm = RankingEngine.topN(items, fakeUsage(), evening, 4);
      expect(am.map(i => i.id).join(',') === pm.map(i => i.id).join(',')).assertFalse();
    });
    it('high_frequency_item_ranks_first', 0, () => {
      const items = makeItems(12);
      const usage = fakeUsage({
        dayCount: (id: string) => id === 'fn-0' ? 10 : 1,
        monthCount: (id: string) => id === 'fn-0' ? 30 : 1
      });
      const top = RankingEngine.topN(items, usage, nowMorning(), 8);
      expect(top[0].id).assertEqual('fn-0');
    });
    it('topn_is_empty_without_candidates', 0, () => {
      expect(RankingEngine.topN(makeItems(0), fakeUsage(), nowMorning(), 4).length).assertEqual(0);
    });
  });
}
