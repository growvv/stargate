import { describe, it, expect } from '@ohos/hypium';
import { LaunchDispatcher } from '../main/ets/launch/LaunchDispatcher';
import { makeFunction, fakeUsage } from './TestFixtures';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';

function verticalFn(): AtomicFunction {
  return makeFunction({ kind: 'vertical', parameters: {
    verticalType: 'navigation', sceneType: 1,
    destinationLatitude: 32.060844, destinationName: '测试地点'
  } });
}

export default function launchTest() {
  describe('LaunchDispatcher', () => {
    it('failure_never_falls_back_to_home', 0, async () => {
      const fn = makeFunction({ kind: 'deeplink', uri: 'bad://x' });
      let calls = 0;
      const starter = async (_want: Object) => { calls++; return false; };
      const r = await LaunchDispatcher.launch(fn, starter);
      expect(r.ok).assertFalse();
      expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
      expect(calls).assertEqual(1); // 只调用一次，不重试、不回退首页
    });
    it('success_records_usage', 0, async () => {
      const fn = makeFunction({ kind: 'deeplink', uri: 'alipays://platformapi/startapp' });
      let calls = 0;
      let recorded = 0;
      const starter = async (_want: Object) => { calls++; return true; };
      const usage = { record: async (_id: string, _at: number) => { recorded++; } };
      const r = await LaunchDispatcher.launch(fn, starter, usage);
      expect(r.ok).assertTrue();
      expect(calls).assertEqual(1);
      expect(recorded).assertEqual(1);
    });
    it('want_is_explicit_with_target_bundle_name', 0, async () => {
      // I1：deeplink 必须是「显式 Want」（带 bundleName），不能是任意 App 都能认领的裸 uri。
      const fn = makeFunction({ kind: 'deeplink', uri: 'alipays://platformapi/startapp' });
      let captured: Object = {};
      const starter = async (want: Object) => { captured = want; return true; };
      await LaunchDispatcher.launch(fn, starter);
      expect((captured as Record<string, Object>)['bundleName']).assertEqual(fn.bundleName);
    });
    it('no_second_route_attempt_on_failure', 0, async () => {
      // 产品 Spec §7：运行时单条最可靠路由，失败即报告，不遍历第二条、不打开首页。
      const fn = makeFunction({ kind: 'shortcut-param', abilityName: 'EntryAbility', moduleName: 'entry' });
      let calls = 0;
      const starter = async (_want: Object) => { calls++; return false; };
      const r = await LaunchDispatcher.launch(fn, starter);
      expect(r.ok).assertFalse();
      expect(calls).assertEqual(1);
      expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
    });
    it('vertical_uses_verticalStarter_not_startAbility', 0, async () => {
      let starterCalls = 0, verticalCalls = 0, seenType = '', seen: Record<string, Object> = {};
      const starter = async (_w: Object) => { starterCalls++; return true; };
      const vertical = async (type: string, p: Record<string, Object>) => {
        verticalCalls++; seenType = type; seen = p; return true;
      };
      const r = await LaunchDispatcher.launch(verticalFn(), starter, undefined, vertical);
      expect(r.ok).assertTrue();
      expect(starterCalls).assertEqual(0);
      expect(verticalCalls).assertEqual(1);
      expect(seenType).assertEqual('navigation');
      expect(seen['sceneType']).assertEqual(1);
      expect(seen['destinationLatitude']).assertEqual(32.060844);
      expect(seen['verticalType']).assertUndefined();
    });
    it('vertical_without_starter_reports_failure_without_fallback', 0, async () => {
      let starterCalls = 0;
      const r = await LaunchDispatcher.launch(verticalFn(),
        async (_w: Object) => { starterCalls++; return true; });
      expect(r.ok).assertFalse();
      expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
      expect(starterCalls).assertEqual(0);
    });
    it('vertical_failure_does_not_call_startAbility', 0, async () => {
      let starterCalls = 0;
      const r = await LaunchDispatcher.launch(verticalFn(),
        async (_w: Object) => { starterCalls++; return true; },
        undefined, async (_t: string, _p: Record<string, Object>) => false);
      expect(r.ok).assertFalse();
      expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
      expect(starterCalls).assertEqual(0);
    });
    it('s2_parameters_pass_through_with_float', 0, async () => {
      let captured: Record<string, Object> = {};
      const fn = makeFunction({ kind: 'deeplink', uri: 'systemnav://routeplan',
        parameters: { destinationLatitude: 32.060844, sceneType: 1, destinationName: '测试地点' } });
      await LaunchDispatcher.launch(fn, async (w: Object) => {
        captured = w as Record<string, Object>; return true;
      });
      const p = captured['parameters'] as Record<string, Object>;
      expect(p['destinationLatitude']).assertEqual(32.060844);
      expect(typeof p['destinationLatitude']).assertEqual('number');
    });
  });
}

// 让 fakeUsage 参与编译（占位引用，确认夹具可用；断言不使用其返回值）
void fakeUsage;
