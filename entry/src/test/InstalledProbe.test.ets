import { describe, it, expect } from '@ohos/hypium';
import { InstalledProbe } from '../main/ets/data/InstalledProbe';
import type { AppTemplateEntry } from '../main/ets/data/AppTemplateCatalog';

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
  });
}
