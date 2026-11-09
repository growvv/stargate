import { describe, it, expect } from '@ohos/hypium';
import { AppTemplateCatalog } from '../main/ets/data/AppTemplateCatalog';
import { SOURCE_CONFIDENCE } from '../main/ets/model/AtomicFunction';

function valid(id: string, scheme: string): Object {
  return { id, appName: '支付宝', bundleName: 'com.alipay', category: '支付', scheme,
    kind: 'third-party', verifiedByProbe: false,
    functions: [{ label: '付款码', route: { kind: 'deeplink', uri: scheme + '://pay' } }] };
}

export default function appTemplateCatalogTest() {
  describe('AppTemplateCatalog', () => {
    it('parse_keeps_valid_and_rejects_bad_entries', 0, () => {
      const out = AppTemplateCatalog.parse(JSON.stringify({ templates: [
        valid('tpl:ok', 'alipays'),
        { id: 'tpl:bad', appName: 'X', bundleName: 'b', category: '不存在', scheme: 'x',
          kind: 'third-party', functions: [{ label: 'x', route: { kind: 'home' } }] }
      ] }));
      expect(out.length).assertEqual(1);
      expect(out[0].id).assertEqual('tpl:ok');
    });
    it('parse_returns_empty_on_invalid_or_empty_text', 0, () => {
      expect(AppTemplateCatalog.parse('').length).assertEqual(0);
      expect(AppTemplateCatalog.parse('{oops').length).assertEqual(0);
    });
    it('parse_blanks_an_invalid_scheme_instead_of_probing_it', 0, () => {
      const out = AppTemplateCatalog.parse(JSON.stringify({ templates: [valid('tpl:x', '1bad:')] }));
      expect(out[0].scheme).assertEqual('');
    });
    it('schemes_are_unique_sorted_and_without_empty', 0, () => {
      const a = AppTemplateCatalog.parse(JSON.stringify({ templates: [valid('a', 'zscheme'), valid('b', 'ascheme'), valid('c', 'zscheme')] }));
      expect(AppTemplateCatalog.schemes(a).join(',')).assertEqual('ascheme,zscheme');
    });
    it('parse_accepts_vertical_template_route', 0, () => {
      // 模板候选也可声明 vertical，但 EffectiveCatalog 不让它生成卡片（Task 3）。
      const out = AppTemplateCatalog.parse(JSON.stringify({ templates: [
        { id: 'tpl:v', appName: '系统能力', bundleName: '', category: '出行', scheme: '',
          kind: 'system', verifiedByProbe: false,
          functions: [{ label: '垂类', route: { kind: 'vertical', parameters: { verticalType: 'mail', sceneType: 1 } } }] }
      ] }));
      expect(out.length).assertEqual(1);
      expect(out[0].functions[0].route.kind).assertEqual('vertical');
    });
    it('template_confidence_is_below_verified_scheme', 0, () => {
      expect(SOURCE_CONFIDENCE['template']).assertEqual(0.5);
      expect(SOURCE_CONFIDENCE['template'] < SOURCE_CONFIDENCE['scheme']).assertTrue();
    });
  });
}
