import { describe, it, expect } from '@ohos/hypium';
import { CardPalette, TILE_COUNT } from '../main/ets/form/CardPalette';
import { PagePalette } from '../main/ets/form/PagePalette';

/**
 * 视觉改版（2026-11-08）：卡片从「纯文字列表」改成 iOS App Library 风格
 * 彩色圆角图标 tile。配色/字形必须是纯逻辑、稳定可复现（同一功能永远同色），
 * 且不能引入真实 App 图标资源（卡片进程无网络/文件系统）。
 */
export default function cardPaletteTest() {
  describe('CardPalette (visual redesign)', () => {
    it('tile_for_same_id_is_stable', 0, () => {
      const a = CardPalette.tileFor('fixture-01');
      const b = CardPalette.tileFor('fixture-01');
      expect(a.start).assertEqual(b.start);
      expect(a.end).assertEqual(b.end);
    });
    it('tile_gradients_are_valid_hex_colors', 0, () => {
      for (let i = 0; i < TILE_COUNT; i++) {
        const t = CardPalette.tileFor('id-' + i);
        expect(/^#[0-9a-f]{6}$/i.test(t.start)).assertTrue();
        expect(/^#[0-9a-f]{6}$/i.test(t.end)).assertTrue();
        expect(t.start === t.end).assertFalse();
      }
    });
    it('distinct_ids_get_varied_tiles', 0, () => {
      const seen = new Set<string>();
      for (let i = 0; i < 16; i++) seen.add(CardPalette.tileFor('fn-' + i).start);
      // 至少铺开 4 种颜色，避免 8 个格子全是一个色。
      expect(seen.size >= 4).assertTrue();
    });
    it('glyph_is_first_character_of_label', 0, () => {
      expect(CardPalette.glyphOf('支付宝付款码')).assertEqual('支');
      expect(CardPalette.glyphOf('微信扫一扫')).assertEqual('微');
      expect(CardPalette.glyphOf('')).assertEqual('·');
    });
    it('ambient_gradient_has_three_stops', 0, () => {
      expect(CardPalette.ambient(false).length).assertEqual(3);
      expect(CardPalette.ambient(true).length).assertEqual(3);
      expect(CardPalette.ambient(true)[0]).assertNotEqual(CardPalette.ambient(false)[0]);
    });
    it('page_glass_tokens_are_valid_argb', 0, () => {
      // D3 结论延伸：内页所有 8 位 token 也必须 alpha 在首位。
      for (const v of [PagePalette.GLASS, PagePalette.GLASS_STRONG, PagePalette.BORDER,
        PagePalette.TEXT_SUB, PagePalette.TEXT_DIM, PagePalette.SHADOW]) {
        expect(/^#[0-9a-f]{8}$/i.test(v)).assertTrue();
      }
      expect(PagePalette.BG.length).assertEqual(3);
    });
    it('inner_pages_use_the_same_light_wallpaper_as_the_card', 0, () => {
      // 精准复刻参考图：内页与首页卡片风格统一，壁纸必须是蓝→青→蓝绿浅色，
      // 不能再用上一版的深藏青（#223A5E / #265A72 / #2F6E6A）。
      const bg = PagePalette.BG;
      expect(bg.length).assertEqual(3);
      for (const c of bg) {
        expect(/^#[0-9a-f]{6}$/i.test(c)).assertTrue();
        expect(c.toUpperCase().startsWith('#22')).assertFalse();
        expect(c.toUpperCase().startsWith('#26')).assertFalse();
      }
      // 与 GlassStyle 的浅色玻璃壁纸逐段一致（统一对齐）。
      expect(bg[0].toUpperCase()).assertEqual('#4A8FD4');
      expect(bg[1].toUpperCase()).assertEqual('#54B0C4');
      expect(bg[2].toUpperCase()).assertEqual('#79C7B0');
    });
    it('inner_pages_expose_nested_frame_tokens', 0, () => {
      // 内页也用「外层文件夹框 → 内层功能框」的嵌套框，token 必须从同一处取，
      // 避免各页各写一套 hex 导致风格不对齐。
      expect(/^#[0-9a-f]{8}$/i.test(PagePalette.FRAME_BG)).assertTrue();
      expect(/^#[0-9a-f]{8}$/i.test(PagePalette.FRAME_BORDER)).assertTrue();
      expect(/^#[0-9a-f]{8}$/i.test(PagePalette.TILE_BG)).assertTrue();
      expect(PagePalette.FRAME_RADIUS > 0).assertTrue();
      expect(PagePalette.TILE_RADIUS > 0).assertTrue();
      expect(PagePalette.FRAME_RADIUS > PagePalette.TILE_RADIUS).assertTrue();
    });
  });
}
