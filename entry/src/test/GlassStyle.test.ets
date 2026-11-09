import { describe, it, expect } from '@ohos/hypium';
import { GlassStyle, ACTIVE_VARIANT } from '../main/ets/form/GlassStyle';
import type { GlassTokens } from '../main/ets/form/GlassStyle';

/**
 * 精准复刻参考图（2026-11-08）：浅色半透明磨砂玻璃 + 嵌套框 + 三版比例迭代。
 * 上一版做成深色藏青是「效果较差」的根因，这里把「浅色玻璃」钉成可回归的断言：
 * 外框填充必须是 15% 白（AARRGGBB #26…）、边框必须是亮白细边（首位透明度高），
 * 不能是 #30000000 那种深色叠层。
 */
export default function glassStyleTest() {
  describe('GlassStyle (light frosted glass + 3 ratio variants)', () => {
    it('frame_glass_is_light_translucent_white_not_dark', 0, () => {
      const t: GlassTokens = GlassStyle.base();
      // D3：8 位 hex 是 AARRGGBB（alpha 在首位）。
      for (const v of [t.frameBg, t.frameBorder, t.tileBg, t.tileBorder]) {
        expect(/^#[0-9a-f]{8}$/i.test(v)).assertTrue();
      }
      // 15% 白外框 + 亮白细边；绝不再是深色 #30000000。
      expect(t.frameBg).assertEqual('#26FFFFFF');
      expect(t.frameBorder.startsWith('#8C')).assertTrue();
      expect(t.frameBg.startsWith('#30')).assertFalse();
      expect(t.frameBg.startsWith('#26')).assertTrue();
    });

    it('wallpaper_is_light_blue_teal_not_dark_navy', 0, () => {
      const t = GlassStyle.base();
      expect(t.wallpaper.length).assertEqual(3);
      for (const c of t.wallpaper) expect(/^#[0-9a-f]{6}$/i.test(c)).assertTrue();
      // 深色版用 #223A5E / #265A72 藏青；浅色参考图不是这些。
      for (const c of t.wallpaper) expect(c.toUpperCase().startsWith('#22')).assertFalse();
      // 三段必须互不相同，形成蓝→青→蓝绿的柔光渐变。
      expect(t.wallpaper[0] === t.wallpaper[1]).assertFalse();
      expect(t.wallpaper[1] === t.wallpaper[2]).assertFalse();
    });

    it('three_ratio_variants_are_distinct_and_ordered', 0, () => {
      expect(GlassStyle.count()).assertEqual(3);
      const a = GlassStyle.variant(0);
      const b = GlassStyle.variant(1);
      const c = GlassStyle.variant(2);
      // 三版「卡片比例」按内框尺寸 / 外框圆角 / 间距单调递增，真机截图逐版对比。
      expect(a.tileSize < b.tileSize).assertTrue();
      expect(b.tileSize < c.tileSize).assertTrue();
      expect(a.radiusFrame < b.radiusFrame).assertTrue();
      expect(b.radiusFrame < c.radiusFrame).assertTrue();
      expect(a.tileGap < c.tileGap).assertTrue();
      // 每版都保留同一套浅色玻璃材质（比例变化不改变配色语言）。
      for (const v of [a, b, c]) expect(v.frameBg).assertEqual('#26FFFFFF');
    });

    it('variant_clamps_out_of_range_and_returns_independent_copies', 0, () => {
      expect(GlassStyle.variant(-9).tileSize).assertEqual(GlassStyle.variant(0).tileSize);
      expect(GlassStyle.variant(99).tileSize).assertEqual(GlassStyle.variant(2).tileSize);
      const one = GlassStyle.variant(1);
      one.tileSize = 1;
      one.wallpaper[0] = '#000000';
      const fresh = GlassStyle.variant(1);
      expect(fresh.tileSize === 1).assertFalse();
      expect(fresh.wallpaper[0]).assertNotEqual('#000000');
    });

    it('three_variants_change_the_outer_frame_aspect_ratio', 0, () => {
      // 三版「调整卡片比例」：外层文件夹框的宽高比逐版变化，真机截图对比。
      const a = GlassStyle.variant(0).frameAspect;
      const b = GlassStyle.variant(1).frameAspect;
      const c = GlassStyle.variant(2).frameAspect;
      expect(a > 0).assertTrue();
      expect(b > 0).assertTrue();
      expect(c > 0).assertTrue();
      // 三版必须真的不同（否则三张截图没区别）。
      expect(a === b || b === c || a === c).assertFalse();
    });

    it('active_variant_is_an_in_range_integer_for_the_three_iterations', 0, () => {
      // 三版迭代只改 ACTIVE_VARIANT 这一个常量（0→1→2），测试不绑死具体值，
      // 保证三版都能绿；最终保留效果最好的一版。
      expect(Number.isInteger(ACTIVE_VARIANT)).assertTrue();
      expect(ACTIVE_VARIANT >= 0).assertTrue();
      expect(ACTIVE_VARIANT < GlassStyle.count()).assertTrue();
    });

    it('page_frame_tokens_exist_for_unified_inner_pages', 0, () => {
      // 首页卡片与搜索页 / 分类页 / 配置页必须共用同一套框体 token。
      const t = GlassStyle.base();
      expect(t.radiusFrame > t.radiusTile).assertTrue();
      expect(t.tileSize > 0).assertTrue();
      expect(t.frameGap > 0).assertTrue();
      expect(t.textPrimary).assertEqual('#FFFFFF');
      expect(/^#[0-9a-f]{8}$/i.test(t.textSecondary)).assertTrue();
    });
  });
}
