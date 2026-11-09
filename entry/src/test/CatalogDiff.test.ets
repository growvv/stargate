import { describe, it, expect } from '@ohos/hypium';
import { CatalogDiff } from '../main/ets/data/CatalogDiff';

export default function catalogDiffTest() {
  describe('CatalogDiff', () => {
    it('diff_reports_added_removed_unchanged_sorted', 0, () => {
      const d = CatalogDiff.diff(['a', 'b'], ['b', 'c']);
      expect(d.added.join(',')).assertEqual('c'); expect(d.removed.join(',')).assertEqual('a'); expect(d.unchanged.join(',')).assertEqual('b');
    });
    it('a_flap_true_false_true_never_confirms_change', 0, () => {
      let s = CatalogDiff.empty(); s = CatalogDiff.confirm(s, ['a'], ['a'], 1000); s = CatalogDiff.confirm(s, [], ['a'], 2000); s = CatalogDiff.confirm(s, ['a'], ['a'], 3000);
      expect(s.installedIds.length).assertEqual(0);
    });
    it('two_true_then_two_false_confirms_install_then_remove', 0, () => {
      let s = CatalogDiff.empty(); s = CatalogDiff.confirm(s, ['a'], ['a'], 1000); s = CatalogDiff.confirm(s, ['a'], ['a'], 2000);
      expect(s.installedIds[0]).assertEqual('a'); s = CatalogDiff.confirm(s, [], ['a'], 3000); expect(s.installedIds.length).assertEqual(1); s = CatalogDiff.confirm(s, [], ['a'], 4000); expect(s.installedIds.length).assertEqual(0);
    });
    it('resetDebounce_clears_streak_but_keeps_confirmed_ids', 0, () => {
      let s = CatalogDiff.confirm(CatalogDiff.confirm(CatalogDiff.empty(), ['a'], ['a'], 1), ['a'], ['a'], 2);
      s = CatalogDiff.resetDebounce(s); expect(s.installedIds[0]).assertEqual('a'); expect(Object.keys(s.streak).length).assertEqual(0);
    });
    it('probedAt_is_the_now_argument', 0, () => { expect(CatalogDiff.confirm(CatalogDiff.empty(), [], ['a'], 4000).probedAt).assertEqual(4000); });
  });
}
