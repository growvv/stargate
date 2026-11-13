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
    it('deeplink_carries_the_viewData_action_required_by_target_skills', 0, async () => {
      // 真机 2026-11-11：卡片点「微博」直接退出。AMS 日志
      //   [implicit_start_processor.cpp340]failed, uri:sinaweibo-<private>
      // 根因：只带 bundleName + uri 的 Want 在应用侧走隐式匹配，而目标 App 的
      // browsable skill 声明的是 actions=[ohos.want.action.viewData] +
      // entities=[entity.system.browsable]；action 为空匹配不上，入口「看着能点、
      // 点了打不开」。真机对照：aa start 补上 -A ohos.want.action.viewData 后，
      // 微博 / QQ音乐 / 支付宝 / 百度地图全部落到目标前台。
      const fn = makeFunction({ kind: 'deeplink', uri: 'sinaweibo://settings/cache' });
      let captured: Record<string, Object> = {};
      await LaunchDispatcher.launch(fn, async (w: Object) => {
        captured = w as Record<string, Object>; return true;
      });
      expect(captured['action']).assertEqual('ohos.want.action.viewData');
      // uri 与 bundleName 必须原样保留（仍然显式指向目标包，不退回裸链接）。
      expect(captured['uri']).assertEqual('sinaweibo://settings/cache');
      expect(captured['bundleName']).assertEqual(fn.bundleName);
    });
    it('explicit_route_action_is_not_overwritten', 0, async () => {
      // route.parameters.action 是能力目录里写明的目标 action，优先于默认值。
      const fn = makeFunction({ kind: 'deeplink', uri: 'weixin://x',
        parameters: { action: 'ohos.want.action.sendData' } });
      let captured: Record<string, Object> = {};
      await LaunchDispatcher.launch(fn, async (w: Object) => {
        captured = w as Record<string, Object>; return true;
      });
      expect(captured['action']).assertEqual('ohos.want.action.sendData');
    });
    it('shortcut_param_routes_do_not_get_a_link_action', 0, async () => {
      // shortcut-param 是显式 ability 启动，加 viewData 反而会被 skill 匹配拒掉。
      const fn = makeFunction({ kind: 'shortcut-param', abilityName: 'EntryAbility', moduleName: 'entry' });
      let captured: Record<string, Object> = {};
      await LaunchDispatcher.launch(fn, async (w: Object) => {
        captured = w as Record<string, Object>; return true;
      });
      expect(captured['action']).assertUndefined();
      expect(captured['abilityName']).assertEqual('EntryAbility');
    });
    it('deeplink_uses_the_link_opener_instead_of_startAbility', 0, async () => {
      // 真机 2026-11-11 二次定位：即使补上 action，startAbility 仍然被生态规则拦
      //   [implicit_start_processor.cpp340]failed, uri:sinaweibo-<private>
      // 三方应用用 startAbility 发起隐式 Want 打不开别的 App；系统为此提供了
      // 专用的 openLink（@since 12，无特殊权限，仅要求前台）。链接类路由必须
      // 走它，而不是自己拼 Want。
      const fn = makeFunction({ kind: 'deeplink', uri: 'sinaweibo://settings/cache' });
      let opened = '';
      let starterCalls = 0;
      const r = await LaunchDispatcher.launch(fn,
        async (_w: Object) => { starterCalls++; return true; },
        undefined, undefined,
        async (uri: string) => { opened = uri; return true; });
      expect(r.ok).assertTrue();
      expect(opened).assertEqual('sinaweibo://settings/cache');
      expect(starterCalls).assertEqual(0); // 不再拼 Want 调 startAbility
    });
    it('link_opener_failure_is_reported_without_falling_back_to_startAbility', 0, async () => {
      // 仍然遵守 Spec §7：单条路由、失败即报告、不换第二条路再试。
      const fn = makeFunction({ kind: 'deeplink', uri: 'bad://x' });
      let starterCalls = 0, openerCalls = 0;
      const r = await LaunchDispatcher.launch(fn,
        async (_w: Object) => { starterCalls++; return true; },
        undefined, undefined,
        async (_u: string) => { openerCalls++; return false; });
      expect(r.ok).assertFalse();
      expect(r.reason).assertEqual('NO_AVAILABLE_ENTRY');
      expect(openerCalls).assertEqual(1);
      expect(starterCalls).assertEqual(0);
    });
    it('deeplink_still_works_when_no_link_opener_is_injected', 0, async () => {
      // 测试替身 / 旧调用点只注入 starter 时保持原行为，不静默失败。
      const fn = makeFunction({ kind: 'deeplink', uri: 'alipays://platformapi/startapp' });
      let starterCalls = 0;
      const r = await LaunchDispatcher.launch(fn, async (_w: Object) => { starterCalls++; return true; });
      expect(r.ok).assertTrue();
      expect(starterCalls).assertEqual(1);
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
