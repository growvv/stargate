import { describe, it, expect } from '@ohos/hypium';
import { isL0, L0_MIN_CONFIDENCE } from '../main/ets/model/AtomicFunction';
import type { AtomicFunction, Route } from '../main/ets/model/AtomicFunction';
import { makeFunction } from './TestFixtures';

function withSource(source: string, confidence: number): AtomicFunction {
  const f = makeFunction({ kind: 'deeplink', uri: 'x://y' });
  f.source = source;
  f.confidence = confidence;
  return f;
}

export default function atomicFunctionTest() {
  describe('AtomicFunction', () => {
    it('L0_min_confidence_is_085', 0, () => {
      expect(L0_MIN_CONFIDENCE).assertEqual(0.85);
    });
    it('verified_sources_are_L0', 0, () => {
      expect(isL0(withSource('linkFeature', 0.95))).assertTrue();
      expect(isL0(withSource('scheme', 0.85))).assertTrue();
      expect(isL0(withSource('shortcut', 1.0))).assertTrue();
      expect(isL0(withSource('manual', 1.0))).assertTrue();
    });
    it('unverified_sources_are_not_L0', 0, () => {
      expect(isL0(withSource('template', 0.5))).assertFalse();
      expect(isL0(withSource('rea', 0.6))).assertFalse();
      expect(isL0(withSource('injection', 0.2))).assertFalse();
      expect(isL0(withSource('linkFeature', 0.84))).assertFalse();
    });
    it('parameters_keep_number_precision', 0, () => {
      const r: Route = {
        kind: 'deeplink', uri: 'systemnav://routeplan',
        parameters: { destinationLatitude: 32.060844, sceneType: 1, destinationName: '测试地点' }
      };
      const f = makeFunction(r);
      const p = f.route.parameters as Record<string, Object>;
      expect(typeof p['destinationLatitude']).assertEqual('number');
      expect(p['destinationLatitude']).assertEqual(32.060844);
      expect(p['sceneType']).assertEqual(1);
    });
    it('vertical_is_a_valid_route_kind', 0, () => {
      const f = makeFunction({ kind: 'vertical', parameters: { verticalType: 'navigation', sceneType: 1 } });
      expect(f.route.kind).assertEqual('vertical');
    });
  });
}
