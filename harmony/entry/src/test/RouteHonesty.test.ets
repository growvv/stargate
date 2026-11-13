import { describe, it, expect } from '@ohos/hypium';
import { RouteHonesty } from '../main/ets/data/RouteHonesty';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';

function fn(id: string, label: string, appName: string, uri: string,
  bundleName: string = 'b', kind: string = 'deeplink'): AtomicFunction {
  const route: Record<string, string> = { kind: kind, uri: uri };
  return { id: id, label: label, appName: appName, bundleName: bundleName,
    category: '娱乐', route: route as Object as AtomicFunction['route'],
    source: 'linkFeature', confidence: 0.95 };
}

export default function routeHonestyTest() {
  describe('RouteHonesty (scheme-only links are dropped)', () => {
    it('bare_scheme_is_detected', 0, () => {
      // 真机 2026-11-12：这四种都只把 App 拉到首页/开屏页。
      expect(RouteHonesty.isBareScheme('dypay1128://')).assertTrue();
      expect(RouteHonesty.isBareScheme('qqmusic://')).assertTrue();
      expect(RouteHonesty.isBareScheme('mailto://')).assertTrue();
      expect(RouteHonesty.isBareScheme('alipay:')).assertTrue();
    });
    it('scheme_with_host_or_path_is_not_bare', 0, () => {
      // 有 host / path 的链接能落到具体页面，不能误判。
      expect(RouteHonesty.isBareScheme('sinaweibo://settings/cache')).assertFalse();
      expect(RouteHonesty.isBareScheme('https://music.qq.com/')).assertFalse();
      expect(RouteHonesty.isBareScheme('alipays://platformapi/startapp?saId=10000007')).assertFalse();
      expect(RouteHonesty.isBareScheme('')).assertFalse();
    });
    it('scheme_only_entries_are_dropped', 0, () => {
      // 用户拍板 2026-11-12：只写到 scheme 的入口直接删除，不改名、不降级。
      // 抖音「付款」dypay1128:// 真机落在首页信息流，兑现不了功能承诺。
      const out = RouteHonesty.apply([
        fn('dy', '付款', '抖音', 'dypay1128://'),
        fn('qy', '存储空间', 'QQ音乐', 'qqmusic://'),
        fn('jd', '存储空间', '京东', 'storage://developer.huawei.com/clearcache')
      ]);
      expect(out.items.length).assertEqual(1);
      expect(out.items[0].id).assertEqual('jd');
      expect(out.dropped.length).assertEqual(2);
      expect(out.dropped.indexOf('dy') >= 0).assertTrue();
      expect(out.dropped.indexOf('qy') >= 0).assertTrue();
    });
    it('open_app_entries_with_a_bare_scheme_are_dropped_too', 0, () => {
      // 「打开微博」sinaweibo:// 也是只到首页 —— 桌面本身就有 App 图标，
      // 目录里再放一格「打开微博」只是噪声，一并删掉。
      const out = RouteHonesty.apply([fn('wb', '打开微博', '微博', 'sinaweibo://')]);
      expect(out.items.length).assertEqual(0);
      expect(out.dropped[0]).assertEqual('wb');
    });
    it('specific_route_with_a_function_label_survives', 0, () => {
      // 微博「存储空间」落到 settings/cache 子页，必须保留。
      const out = RouteHonesty.apply([fn('wb', '存储空间', '微博', 'sinaweibo://settings/cache')]);
      expect(out.items.length).assertEqual(1);
      expect(out.items[0].label).assertEqual('存储空间');
      expect(out.dropped.length).assertEqual(0);
    });
    it('does_not_mutate_the_input_array_or_items', 0, () => {
      // 能力库快照被卡片/页面共享，闸门不能就地改动。
      const items: AtomicFunction[] = [fn('dy', '付款', '抖音', 'dypay1128://'),
        fn('wb', '存储空间', '微博', 'sinaweibo://settings/cache')];
      RouteHonesty.apply(items);
      expect(items.length).assertEqual(2);
      expect(items[0].label).assertEqual('付款');
    });
    it('non_link_routes_are_never_touched', 0, () => {
      // vertical / shortcut-param 没有 URI，不参与这条判定。
      const vertical: AtomicFunction = { id: 'v', label: '导航', appName: '系统', bundleName: '',
        category: '出行', route: { kind: 'vertical', parameters: { verticalType: 'navigation' } },
        source: 'manual', confidence: 1.0 };
      const out = RouteHonesty.apply([vertical]);
      expect(out.items.length).assertEqual(1);
      expect(out.dropped.length).assertEqual(0);
    });
    it('http_links_with_a_host_are_kept', 0, () => {
      // 「打开京东」https://linkst.m.jd.com/ 有 host，能落到落地页，保留。
      const out = RouteHonesty.apply([fn('jd', '打开京东', '京东', 'https://linkst.m.jd.com/')]);
      expect(out.items.length).assertEqual(1);
    });
  });
}
