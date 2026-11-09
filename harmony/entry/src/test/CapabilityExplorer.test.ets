import { describe, it, expect } from '@ohos/hypium';
import { CapabilityExplorer } from '../main/ets/data/CapabilityExplorer';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';

function item(id: string, source: string): AtomicFunction {
  return {
    id: id,
    label: id,
    appName: '测试 App',
    bundleName: 'com.example.test',
    category: '工具效率',
    route: { kind: 'deeplink', uri: 'test://open' },
    source: source,
    confidence: 0.5
  };
}

export default function capabilityExplorerTest() {
  describe('CapabilityExplorer', () => {
    it('maps_evidence_sources_to_levels', 0, () => {
      expect(CapabilityExplorer.levelOf('scheme')).assertEqual('verified');
      expect(CapabilityExplorer.levelOf('rea')).assertEqual('rea');
      expect(CapabilityExplorer.levelOf('injection')).assertEqual('ui-test');
      expect(CapabilityExplorer.levelOf('future')).assertEqual('unknown');
    });
    it('summarizes_verified_and_pending_items', 0, () => {
      const s = CapabilityExplorer.summarize([
        item('a', 'shortcut'), item('b', 'rea'), item('c', 'injection'), item('d', 'manual')
      ]);
      expect(s.total).assertEqual(4);
      expect(s.verified).assertEqual(1);
      expect(s.rea).assertEqual(1);
      expect(s.uiTest).assertEqual(1);
      expect(s.manual).assertEqual(1);
      expect(s.unknown).assertEqual(0);
    });
  });
}
