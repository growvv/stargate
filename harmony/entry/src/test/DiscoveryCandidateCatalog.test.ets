import { describe, it, expect } from '@ohos/hypium';
import { DiscoveryCandidateCatalog } from '../main/ets/data/DiscoveryCandidateCatalog';

export default function discoveryCandidateCatalogTest() {
  describe('DiscoveryCandidateCatalog', () => {
    it('parses_declared_and_unknown_records_without_promoting_them', 0, () => {
      const out = DiscoveryCandidateCatalog.parse(JSON.stringify({ records: [
        { id: 'a', bundleName: 'com.a', appName: 'A', category: '工具效率', status: 'declared',
          sourceLayer: 'L1-L2', schemes: ['a'], linkFeatures: [], shortcuts: [], pathHints: [],
          entrypointCount: 1, productionEligible: false },
        { id: 'bad' }
      ] }));
      expect(out.length).assertEqual(1);
      expect(out[0].productionEligible).assertFalse();
      expect(DiscoveryCandidateCatalog.statusLabel(out[0].status)).assertContain('待验证');
      expect(DiscoveryCandidateCatalog.hintPreview(out[0])).assertContain('a://');
    });
    it('keeps_empty_apps_explicit', 0, () => {
      const out = DiscoveryCandidateCatalog.parse(JSON.stringify({ records: [
        { id: 'b', bundleName: 'com.b', appName: 'B', category: '其他', status: 'unknown', sourceLayer: 'unknown' }
      ] }));
      expect(out.length).assertEqual(1);
      expect(DiscoveryCandidateCatalog.hintPreview(out[0])).assertContain('未发现');
    });
    it('filters_by_app_bundle_or_declared_hint', 0, () => {
      const out = DiscoveryCandidateCatalog.parse(JSON.stringify({ records: [
        { id: 'a', bundleName: 'com.jd.hm.mall', appName: '京东', category: '购物', status: 'declared',
          sourceLayer: 'L1-L2', schemes: ['storage'], linkFeatures: ['AppStorageMgmt'], shortcuts: [], pathHints: [], entrypointCount: 2 },
        { id: 'b', bundleName: 'com.amap.hmapp', appName: '高德地图', category: '出行', status: 'declared',
          sourceLayer: 'L1-L2', schemes: ['systemnav'], linkFeatures: ['RoutePlan'], shortcuts: [], pathHints: [], entrypointCount: 2 }
      ] }));
      expect(DiscoveryCandidateCatalog.filter(out, '京东').length).assertEqual(1);
      expect(DiscoveryCandidateCatalog.filter(out, 'RoutePlan')[0].appName).assertEqual('高德地图');
    });
  });
}
