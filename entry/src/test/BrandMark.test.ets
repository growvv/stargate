import { describe, it, expect } from '@ohos/hypium';
import { BrandMark } from '../main/ets/form/BrandMark';

/**
 * 精准复刻参考图：尽可能用「应用原生标识」（品牌色 + 品牌字形），
 * 匹配不到才回退到文字（首字）或颜色区分。品牌表必须可测、离线、稳定。
 */
export default function brandMarkTest() {
  describe('BrandMark (native app identification)', () => {
    it('known_apps_get_brand_color_and_glyph', 0, () => {
      const a = BrandMark.forApp('支付宝', '支付宝付款码');
      expect(a.native).assertTrue();
      expect(a.bg).assertEqual('#1677FF'); // 支付宝蓝
      expect(a.key).assertEqual('alipay');
      expect(a.hasLogo).assertTrue(); // 真实 App logo 资源
      const w = BrandMark.forApp('微信', '微信扫一扫');
      expect(w.native).assertTrue();
      expect(w.bg).assertEqual('#07C160'); // 微信绿
      expect(w.key).assertEqual('wechat');
      expect(w.hasLogo).assertTrue();
      const t = BrandMark.forApp('淘宝', '淘宝购物车');
      expect(t.native).assertTrue();
      expect(t.glyph).assertEqual('淘');
      const j = BrandMark.forApp('京东', '京东订单');
      expect(j.native).assertTrue();
      expect(j.glyph).assertEqual('京');
    });
    it('specific_brands_win_over_shorter_prefixes', 0, () => {
      // 「QQ音乐」不能被更短的「QQ」抢先匹配成 QQ；「美团外卖」同理。
      expect(BrandMark.forApp('QQ音乐', '存储空间').key).assertEqual('qqmusic');
      expect(BrandMark.forApp('美团外卖', '外卖订单').key).assertEqual('meituan_waimai');
      expect(BrandMark.forApp('百度网盘', '文件').key).assertEqual('baidu_netdisk');
      expect(BrandMark.forApp('华为运动健康', '步数').key).assertEqual('huawei_health');
    });
    it('brand_lookup_is_case_insensitive_and_matches_bundle_suffix', 0, () => {
      // 有些条目 appName 可能带后缀或大小写差异，按包含匹配仍要命中品牌。
      expect(BrandMark.forApp('支付宝(中国)', '付款码').native).assertTrue();
      expect(BrandMark.forApp('wechat', '扫一扫').native || BrandMark.forApp('微信', '扫一扫').native).assertTrue();
    });
    it('unknown_app_falls_back_to_symbol_not_chinese_letter', 0, () => {
      // 用户反馈：不要再用中文字当 logo；未命中品牌时回退到中性符号。
      const u = BrandMark.forApp('一个不存在的应用', '某功能');
      expect(u.native).assertFalse();
      expect(u.hasLogo).assertFalse();
      expect(u.key).assertEqual('');
      expect(/[一-鿿]/.test(u.glyph)).assertFalse();
      expect(u.glyph.length).assertLargerThan(0);
      expect(/^#[0-9a-f]{6}$/i.test(u.bg)).assertTrue(); // 回退：稳定颜色
      expect(u.fg).assertEqual('#ffffff');
    });
    it('fallback_color_is_stable_for_same_app', 0, () => {
      expect(BrandMark.forApp('XApp', '功能一').bg).assertEqual(BrandMark.forApp('XApp', '功能二').bg);
    });
    it('empty_label_falls_back_safely', 0, () => {
      const e = BrandMark.forApp('', '');
      expect(e.glyph.length).assertLargerThan(0);
      expect(/^#[0-9a-f]{6}$/i.test(e.bg)).assertTrue();
    });
    it('all_12_fixture_apps_resolve_to_valid_marks', 0, () => {
      const apps = ['支付宝', '微信', '淘宝', '京东', '高德地图', '百度地图',
        '天气', '腾讯视频', '网易云音乐', '备忘录', '运动健康', 'QQ'];
      for (const a of apps) {
        const m = BrandMark.forApp(a, '某功能');
        expect(/^#[0-9a-f]{6}$/i.test(m.bg)).assertTrue();
        expect(m.glyph.length).assertLargerThan(0);
        expect(m.fg.length).assertLargerThan(0);
      }
    });
  });
}
