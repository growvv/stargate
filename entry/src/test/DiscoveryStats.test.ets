import { describe, it, expect } from '@ohos/hypium';
import { DiscoveryStats } from '../main/ets/data/DiscoveryStats';

export default function discoveryStatsTest() {
  describe('DiscoveryStats', () => {
    it('matches_the_declaration_ledger_and_keeps_verified_catalog_separate', 0, () => {
      const s = DiscoveryStats.current();
      expect(s.bundleCount).assertEqual(48);
      expect(s.schemes).assertEqual(37);
      expect(s.linkFeatures).assertEqual(22);
      expect(s.shortcuts).assertEqual(17);
      expect(s.withoutHints).assertEqual(11);
      expect(s.verifiedCatalogItems).assertEqual(4);
      expect(s.runtimeCases).assertEqual(87);
      expect(s.runtimeCandidates).assertEqual(67);
      expect(s.runtimeConfirmed).assertEqual(4);
      expect(DiscoveryStats.headline()).assertContain('48');
      expect(DiscoveryStats.boundary()).assertContain('REA');
    });
  });
}
