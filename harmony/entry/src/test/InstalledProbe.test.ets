import { describe, it, expect } from '@ohos/hypium';
import { InstalledProbe } from '../main/ets/data/InstalledProbe';
import type { AppTemplateEntry } from '../main/ets/data/AppTemplateCatalog';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';

function tpl(id: string, scheme: string): AppTemplateEntry {
  return { id, appName: id, bundleName: 'b', category: '工具效率', scheme, kind: 'third-party',
    verifiedByProbe: false, functions: [{ label: '功能', route: { kind: 'deeplink', uri: scheme ? scheme + '://x' : '' } }] };
}

export default function installedProbeTest() {
  describe('InstalledProbe', () => {
    it('installed_ids_are_only_templates_whose_scheme_opens', 0, () => {
      const out = InstalledProbe.installedIds([tpl('tpl:a', 'schemeA'), tpl('tpl:b', 'schemeB'), tpl('tpl:c', '')], { canOpen: (s: string) => s === 'schemeA' });
      expect(out.length).assertEqual(1); expect(out[0]).assertEqual('tpl:a');
    });
    it('empty_scheme_never_calls_the_probe', 0, () => {
      let count = 0;
      InstalledProbe.installedIds([tpl('tpl:a', '')], { canOpen: (_s: string) => { count++; return true; } });
      expect(count).assertEqual(0);
    });
    it('one_throwing_probe_is_false_and_does_not_abort_batch', 0, () => {
      const probe = { canOpen: (s: string) => { if (s === 'bad') throw new Error('17700056'); return s === 'ok'; } };
      const out = InstalledProbe.installedIds([tpl('tpl:x', 'bad'), tpl('tpl:y', 'ok')], probe);
      expect(out.join(',')).assertEqual('tpl:y');
    });
    it('installed_ids_are_sorted_for_determinism', 0, () => {
      const out = InstalledProbe.installedIds([tpl('tpl:z', 'z'), tpl('tpl:a', 'a')], { canOpen: (_s: string) => true });
      expect(out.join(',')).assertEqual('tpl:a,tpl:z');
    });

    it('presence_falls_back_to_link_probing_when_every_query_is_unknown', 0, () => {
      // 真机 2026-11-11：getBundleInfoSync 对**本机所有包**都返回 8521226
      // （连已安装的支付宝、微博也一样）。SDK 明确写着
      //   "The application requires to be a system application when requesting
      //    the permission of ohos.permission.GET_BUNDLE_INFO."
      // 我们是三方应用，所以安装态探针永远是 undefined。若此时仍只信 presence，
      // 「最近添加」永远探测不到新装的 App —— 卡片永远是目录尾部的默认填充。
      // 修法：presence 一条明确结论都没有时，退回 canOpenLink 链接探测。
      const items = makeItemsForDetect();
      const presence = { installed: (_b: string) => undefined as boolean | undefined };
      const routeProbe = {
        canOpen: (_s: string) => true,
        canOpenRoute: (r: { uri?: string }) => (r.uri ?? '').indexOf('opens') >= 0
      };
      const out = InstalledProbe.detectedBundlesBest(items, presence, routeProbe);
      // 退回到链接探测后，只有能打开的 App 被认出来（不是空数组）。
      expect(out.join(',')).assertEqual('com.opens');
    });

    it('presence_answers_win_over_link_probing_when_available', 0, () => {
      // presence 可用时以它为准：它能覆盖 file:// / vertical 这类没有可归属
      // scheme 的条目，链接探测认不出来。
      const items = makeItemsForDetect();
      const presence = { installed: (b: string) => b === 'com.presence' };
      const routeProbe = {
        canOpen: (_s: string) => true,
        canOpenRoute: (_r: { uri?: string }) => true   // 链接探测会说全都可用
      };
      const out = InstalledProbe.detectedBundlesBest(items, presence, routeProbe);
      expect(out.join(',')).assertEqual('com.presence');
    });

    it('presence_answered_no_install_is_respected_not_overridden', 0, () => {
      // presence 明确回答「一个都没装」是有效结论，不能被链接探测推翻。
      const items = makeItemsForDetect();
      const presence = { installed: (_b: string) => false };
      const routeProbe = { canOpen: (_s: string) => true, canOpenRoute: (_r: { uri?: string }) => true };
      const out = InstalledProbe.detectedBundlesBest(items, presence, routeProbe);
      expect(out.length).assertEqual(0);
    });
  });
}

/** 两个 App：com.opens 有可打开的 scheme，com.closed 没有。 */
function makeItemsForDetect(): AtomicFunction[] {
  return [
    { id: 'a', label: '功能A', appName: 'A', bundleName: 'com.opens', category: '工具效率',
      route: { kind: 'deeplink', uri: 'opens://x' } },
    { id: 'b', label: '功能B', appName: 'B', bundleName: 'com.closed', category: '工具效率',
      route: { kind: 'deeplink', uri: 'closed://x' } },
    { id: 'c', label: '功能C', appName: 'C', bundleName: 'com.presence', category: '工具效率',
      route: { kind: 'deeplink', uri: 'closed2://x' } }
  ];
}
