import { describe, it, expect } from '@ohos/hypium';
import { EffectiveCatalog } from '../main/ets/data/EffectiveCatalog';
import type { AppTemplateEntry } from '../main/ets/data/AppTemplateCatalog';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';

function l1(id: string, appName: string): AtomicFunction {
  return { id, label: '功能', appName, bundleName: 'b', category: '支付',
    route: { kind: 'deeplink', uri: 'x://y' }, source: 'scheme', confidence: 0.85 };
}
function nonL0(id: string, appName: string): AtomicFunction {
  const f = l1(id, appName);
  f.source = 'template';
  f.confidence = 0.5;
  return f;
}
function tpl(id: string, appName: string, scheme: string): AppTemplateEntry {
  return { id, appName, bundleName: 'b', category: '支付', scheme, kind: 'third-party', verifiedByProbe: false,
    functions: [{ label: '付款码', route: { kind: 'deeplink', uri: scheme + '://pay' } }] };
}

export default function effectiveCatalogTest() {
  describe('EffectiveCatalog', () => {
    it('uninstalled_template_never_creates_a_card', 0, () => {
      // 形态 A / L0 过滤：模板未安装时不注入，也不隐藏同名 L0 条目。
      const out = EffectiveCatalog.build([l1('fn-a', '支付宝')],
        [tpl('tpl:alipay', '支付宝', 'alipays')], new Set<string>());
      expect(out.length).assertEqual(1);
      expect(out[0].id).assertEqual('fn-a');
    });
    it('installed_template_never_produces_card', 0, () => {
      const out = EffectiveCatalog.build([], [tpl('tpl:alipay', '支付宝', 'alipays')],
        new Set(['tpl:alipay']));
      expect(out.length).assertEqual(0);
    });
    it('L0_survives_installed_same_name_template', 0, () => {
      const out = EffectiveCatalog.build([l1('fn-a', '支付宝')],
        [tpl('tpl:alipay', '支付宝', 'alipays')], new Set(['tpl:alipay']));
      expect(out.length).assertEqual(1);
      expect(out[0].id).assertEqual('fn-a');
    });
    it('non_L0_l1_entry_is_filtered_even_if_present', 0, () => {
      // 外部可替换配置被塞入 template/0.5 时，不能变成可点击卡片。
      const out = EffectiveCatalog.build([nonL0('fn-t', '微信')],
        [tpl('tpl:wechat', '微信', 'weixin')], new Set(['tpl:wechat']));
      expect(out.length).assertEqual(0);
    });
    it('result_is_sorted_by_id', 0, () => {
      const out = EffectiveCatalog.build([l1('z', '甲'), l1('a', '乙')], [], new Set<string>());
      expect(out[0].id).assertEqual('a');
    });
  });
}
