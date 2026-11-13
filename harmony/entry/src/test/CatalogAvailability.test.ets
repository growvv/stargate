import { describe, it, expect } from '@ohos/hypium';
import { CatalogAvailability, schemeOf, isSpecificScheme } from '../main/ets/data/CatalogAvailability';
import type { AtomicFunction, Route } from '../main/ets/model/AtomicFunction';
import type { RouteProbe, PresenceProbe } from '../main/ets/data/InstalledProbe';

/**
 * 2026-11-11 换设备真机验证：目录是随包发布的静态 JSON，换一台没装 WPS 的手机
 * 后，WPS 图标仍出现在卡片和搜索页里，点下去失败。这里钉住「按当前设备收敛」
 * 的三条规则：整包剔除、入口级剔除、探针失效时 fail-open。
 */
function fn(id: string, bundle: string, uri: string): AtomicFunction {
  return {
    id: id, label: id, appName: bundle, bundleName: bundle, category: '工具效率',
    route: { kind: 'deeplink', uri: uri }, source: 'scheme', confidence: 0.85
  };
}

class OpenOnly implements RouteProbe {
  private open: string[];
  constructor(open: string[]) { this.open = open; }
  canOpenRoute(route: Route): boolean {
    const uri = route.uri ?? '';
    for (const s of this.open) if (uri.indexOf(s) === 0) return true;
    return false;
  }
}

class Presence implements PresenceProbe {
  private installedSet: string[];
  constructor(installed: string[]) { this.installedSet = installed; }
  installed(bundleName: string): boolean | undefined {
    return this.installedSet.indexOf(bundleName) >= 0;
  }
}

class BrokenProbe implements RouteProbe {
  canOpenRoute(_route: Route): boolean {
    throw new Error('17700056 scheme not in querySchemes');
  }
}

export default function catalogAvailabilityTest() {
  describe('CatalogAvailability', () => {
    it('parses_scheme_and_rejects_placeholders', 0, () => {
      expect(schemeOf('weixin://betalogin')).assertEqual('weixin');
      expect(schemeOf('WEIXIN://x')).assertEqual('weixin');
      expect(schemeOf('{{SECRET_x}}://')).assertEqual('');
      expect(schemeOf('file://')).assertEqual('file');
      expect(schemeOf('')).assertEqual('');
    });

    it('generic_schemes_are_not_app_identity', 0, () => {
      expect(isSpecificScheme('file')).assertFalse();
      expect(isSpecificScheme('https')).assertFalse();
      expect(isSpecificScheme('storage')).assertFalse();
      expect(isSpecificScheme('weixin')).assertTrue();
    });

    it('drops_every_entry_of_an_uninstalled_app', 0, () => {
      // 设备上装了支付宝、没装 WPS：WPS 的条目必须整包消失。
      const items = [
        fn('wps-1', 'cn.wps.office.hap', 'ksodoccenter://'),
        fn('ali-1', 'com.alipay.mobile.client', 'alipays://platformapi/startapp'),
        fn('ali-2', 'com.alipay.mobile.client', 'alipayshare://open/share')
      ];
      const r = CatalogAvailability.evaluate(items, new OpenOnly(['alipays']),
        new Presence(['com.alipay.mobile.client']));
      expect(r.probeAvailable).assertTrue();
      expect(r.availableIds.join(',')).assertEqual('ali-1,ali-2');
      expect(r.missingBundles.join(',')).assertEqual('cn.wps.office.hap');
      expect(r.droppedIds.join(',')).assertEqual('wps-1');
    });

    it('drops_only_the_unreachable_entry_within_an_installed_app', 0, () => {
      // App 在，但其中一条 scheme 打不开 → 只剔除这一条，不连坐整个 App。
      const items = [
        fn('ali-1', 'com.alipay.mobile.client', 'alipays://a'),
        fn('ali-2', 'com.alipay.mobile.client', 'apmqpdispatch://')
      ];
      const r = CatalogAvailability.evaluate(items, new OpenOnly(['alipays']),
        new Presence(['com.alipay.mobile.client']));
      expect(r.availableIds.join(',')).assertEqual('ali-1');
      expect(r.droppedIds.join(',')).assertEqual('ali-2');
    });

    it('generic_scheme_entries_survive_when_the_app_is_installed', 0, () => {
      // file:// / vertical 这类没有可归属 scheme 的条目不能做入口级判定，
      // 只要 App 已安装就保留（否则日历 / 邮件会整片消失）。
      const items = [
        fn('cal', 'com.huawei.hmos.calendar', 'file://'),
        fn('vert', 'com.stargate.functionpanel', '')
      ];
      const r = CatalogAvailability.evaluate(items, new OpenOnly([]),
        new Presence(['com.huawei.hmos.calendar', 'com.stargate.functionpanel']));
      expect(r.probeAvailable).assertTrue();
      expect(r.availableIds.join(',')).assertEqual('cal,vert');
      expect(r.missingBundles.length).assertEqual(0);
    });

    it('falls_back_to_link_probe_when_presence_is_unknown', 0, () => {
      const items = [
        fn('a', 'com.a', 'schemea://'),
        fn('b', 'com.b', 'schemeb://')
      ];
      const r = CatalogAvailability.evaluate(items, new OpenOnly(['schemea']));
      expect(r.probeAvailable).assertTrue();
      expect(r.availableIds.join(',')).assertEqual('a');
      expect(r.source).assertEqual('link');
    });

    it('fails_open_when_the_probe_is_unusable', 0, () => {
      // 关键安全阀：querySchemes 漏配 → 每条 canOpenLink 都抛 → 必须原样返回，
      // 绝不能把整个目录清空（那会让应用变成空壳）。
      const items = [fn('a', 'com.a', 'schemea://'), fn('b', 'com.b', 'schemeb://')];
      const r = CatalogAvailability.evaluate(items, new BrokenProbe());
      expect(r.probeAvailable).assertFalse();
      expect(r.availableIds.join(',')).assertEqual('a,b');
      expect(r.droppedIds.length).assertEqual(0);
    });

    it('treats_an_exception_as_unknown_not_as_unavailable', 0, () => {
      // 真机踩到：canOpenLink('alipays://') 抛 17700055（链接不完整），
      // 旧实现把异常当 false，已安装的支付宝被整包剔除，搜索得到空结果。
      // 异常必须表示「不知道」，条目保留。
      const items = [fn('ali-1', 'com.alipay.mobile.client', 'alipays://a')];
      const r = CatalogAvailability.evaluate(items, new BrokenProbe(),
        new Presence(['com.alipay.mobile.client']));
      expect(r.availableIds.join(',')).assertEqual('ali-1');
      expect(r.droppedIds.length).assertEqual(0);
    });

    it('drops_everything_only_when_the_system_says_closed', 0, () => {
      // 布尔探针对每条都返回 false = 系统明确说「没人认领」（这些 App 都没装），
      // 这时清空是正确结果，不是探针失效。
      const items = [fn('a', 'com.a', 'schemea://'), fn('b', 'com.b', 'schemeb://')];
      const r = CatalogAvailability.evaluate(items, new OpenOnly([]));
      expect(r.probeAvailable).assertTrue();
      expect(r.availableIds.length).assertEqual(0);
      expect(r.missingBundles.join(',')).assertEqual('com.a,com.b');
    });

    it('empty_catalog_is_a_no_op', 0, () => {
      const r = CatalogAvailability.evaluate([], new OpenOnly(['x']));
      expect(r.availableIds.length).assertEqual(0);
      expect(r.probeAvailable).assertFalse();
    });

    it('keeps_input_order_of_available_ids', 0, () => {
      const items = [
        fn('z', 'com.z', 'schemez://'),
        fn('a', 'com.a', 'schemea://')
      ];
      const r = CatalogAvailability.evaluate(items, new OpenOnly(['schemez', 'schemea']));
      expect(r.availableIds.join(',')).assertEqual('z,a');
    });
  });
}
