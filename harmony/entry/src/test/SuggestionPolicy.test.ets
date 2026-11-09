import { describe, it, expect } from '@ohos/hypium';
import { RankingEngine } from '../main/ets/recommend/RankingEngine';
import { makeItems, fakeUsage, nowMorning } from './TestFixtures';

export default function suggestionPolicyTest() {
  describe('SuggestionPolicy', () => {
    it('suggestions_are_usage_driven_only', 0, () => {
      const items = makeItems(12);
      const base = RankingEngine.topN(items, fakeUsage(), nowMorning(), 8);
      const heavy = RankingEngine.topN(
        items, fakeUsage({ dayCount: (id: string) => id === 'fn-11' ? 50 : 0 }), nowMorning(), 8);
      expect(base.length).assertEqual(8);
      expect(heavy.length).assertEqual(8);
      expect(heavy[0].id).assertEqual('fn-11'); // 用量变化即改变建议区；无 pinned/收藏可固定它
    });
  });
}
