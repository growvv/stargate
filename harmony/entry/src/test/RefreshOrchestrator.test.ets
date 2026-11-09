import { describe, it, expect } from '@ohos/hypium';
import { RefreshOrchestrator } from '../main/ets/form/RefreshOrchestrator';
import { CatalogDiff } from '../main/ets/data/CatalogDiff';
import type { AppTemplateEntry } from '../main/ets/data/AppTemplateCatalog';
import type { RefreshInput } from '../main/ets/form/RefreshOrchestrator';
import type { RouteProbe } from '../main/ets/data/InstalledProbe';
import { fakeUsage, makeFunction } from './TestFixtures';
import type { AtomicFunction, Route } from '../main/ets/model/AtomicFunction';

class AlwaysOpenRoute implements RouteProbe {
  canOpenRoute(_route: Route): boolean {
    return true;
  }
}

/** 一条 L0 已验证条目：模板安装与否都不该改变它。 */
function verifiedL0(): AtomicFunction {
  const f = makeFunction({ kind: 'deeplink', uri: 'verified://x' });
  f.id = 'verified-a';
  f.source = 'scheme';
  f.confidence = 0.85;
  return f;
}

function template(): AppTemplateEntry {
  return {
    id: 'tpl:demo', appName: '演示应用', bundleName: 'com.example.demo',
    category: '工具效率', scheme: 'demo', kind: 'third-party', verifiedByProbe: false,
    functions: [{ label: '搜索', route: { kind: 'deeplink', uri: 'demo://search' } }]
  };
}

function input(overrides?: Partial<RefreshInput>): RefreshInput {
  const base: RefreshInput = {
    l1: [verifiedL0()], templates: [template()], probe: { canOpen: (_scheme: string) => true },
    prev: CatalogDiff.empty(), usage: fakeUsage(), now: 1000, formId: '',
    failure: '', failureAt: 0, dark: false, blurAvailable: true,
    appVersionFingerprint: ''
  };
  return {
    l1: overrides?.l1 ?? base.l1,
    templates: overrides?.templates ?? base.templates,
    probe: overrides?.probe ?? base.probe,
    prev: overrides?.prev ?? base.prev,
    usage: overrides?.usage ?? base.usage,
    now: overrides?.now ?? base.now,
    formId: overrides?.formId ?? base.formId,
    failure: overrides?.failure ?? base.failure,
    failureAt: overrides?.failureAt ?? base.failureAt,
    dark: overrides?.dark ?? base.dark,
    blurAvailable: overrides?.blurAvailable ?? base.blurAvailable,
    appVersionFingerprint: overrides?.appVersionFingerprint ?? base.appVersionFingerprint,
    routeProbe: overrides?.routeProbe,
    categoryOrder: overrides?.categoryOrder
  };
}

export default function refreshOrchestratorTest() {
  describe('RefreshOrchestrator', () => {
    it('templates_never_change_effective_count_after_two_probes', 0, () => {
      // 形态 A：模板双次确认只影响安装 diff，不再注入卡片。
      let r = RefreshOrchestrator.resolve(input({ now: 1000 }));
      expect(r.effectiveCount).assertEqual(1);
      expect(r.effective[0].id).assertEqual('verified-a');
      r = RefreshOrchestrator.resolve(input({ now: 2000, prev: r.snapshot }));
      expect(r.effectiveCount).assertEqual(1);
      expect(r.diff.added.join(',')).assertEqual('tpl:demo');
    });
    it('uninstalled_template_never_removes_L0_entry', 0, () => {
      let r = RefreshOrchestrator.resolve(input({ now: 1000 }));
      r = RefreshOrchestrator.resolve(input({ now: 2000, prev: r.snapshot,
        probe: { canOpen: (_scheme: string) => false } }));
      r = RefreshOrchestrator.resolve(input({ now: 3000, prev: r.snapshot,
        probe: { canOpen: (_scheme: string) => false } }));
      expect(r.effectiveCount).assertEqual(1);
      expect(r.effective[0].id).assertEqual('verified-a');
    });
    it('effective_contains_only_L0_even_with_installed_template', 0, () => {
      const r = RefreshOrchestrator.resolve(input({ now: 1000 }));
      expect(r.effective.some((f: AtomicFunction) => f.source === 'template')).assertFalse();
    });
    it('preserves_failure_feedback_while_rebuilding_the_catalog', 0, () => {
      const r = RefreshOrchestrator.resolve(input({
        failure: '『搜索』暂无可用直达入口', failureAt: 1000, now: 1000
      }));
      expect(r.binding.failure).assertContain('暂无可用直达入口');
      expect(r.binding.failureAt).assertEqual(1000);
    });
    it('version_change_resets_debounce_before_confirmation', 0, () => {
      const previous = CatalogDiff.confirm(CatalogDiff.empty(), ['tpl:demo'], ['tpl:demo'], 1);
      const r = RefreshOrchestrator.resolve(input({ prev: previous, now: 2,
        appVersionFingerprint: 'v2' }));
      expect(r.snapshot.installedIds.length).assertEqual(0);
      expect(r.snapshot.appVersionFingerprint).assertEqual('v2');
    });
    it('does_not_mutate_the_previous_snapshot', 0, () => {
      const previous = CatalogDiff.empty();
      RefreshOrchestrator.resolve(input({ prev: previous }));
      expect(previous.installedIds.length).assertEqual(0);
      expect(Object.keys(previous.streak).length).assertEqual(0);
    });
    it('route_probe_seeds_recent_added_baseline_on_first_run', 0, () => {
      // 首次开启探测：已有 App 全部记为基线 0，不算「最近添加」。
      const r = RefreshOrchestrator.resolve(input({
        now: 1000, routeProbe: new AlwaysOpenRoute()
      }));
      expect(r.snapshot.bundlesProbedAt).assertEqual(1000);
      expect(r.snapshot.bundleFirstSeen['com.stargate.demo']).assertEqual(0);
    });
    it('route_probe_marks_a_newly_detected_bundle_as_recently_added', 0, () => {
      const first = RefreshOrchestrator.resolve(input({
        now: 1000, routeProbe: new AlwaysOpenRoute()
      }));
      const added = verifiedL0();
      added.id = 'verified-b';
      added.bundleName = 'com.new.app';
      added.appName = '新应用';
      const second = RefreshOrchestrator.resolve(input({
        l1: [verifiedL0(), added], prev: first.snapshot, now: 2000,
        routeProbe: new AlwaysOpenRoute()
      }));
      expect(second.snapshot.bundleFirstSeen['com.new.app']).assertEqual(2000);
      expect(second.snapshot.bundleFirstSeen['com.stargate.demo']).assertEqual(0);
      // 卡片「最近添加」框应把新检测到的 App 排在默认填充之前。
      expect(second.binding.frames[1].items[0].id).assertEqual('verified-b');
    });
  });
}
