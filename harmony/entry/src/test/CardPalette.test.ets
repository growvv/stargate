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
    it('inner_pages_use_a_neutral_backdrop_that_keeps_white_text_readable', 0, () => {
      // 用户两次真机反馈的合并结论（2026-11-11）：
      //  第一次「不要用现在那个蓝色……现在这个有点太深了」；
      //  第二次「文字还是白色好看，背景……跟白色有一点对比度就行了，
      //          但也不能是纯透明的纯白吧？我白色我就看不见了」。
      // 所以底色必须是：中性（无饱和色相）、比纯白深（白字有对比度）、
      // 也不能退回原来那条饱和蓝壁纸。
      const bg = PagePalette.BG;
      expect(bg.length).assertEqual(3);
      for (const c of bg) {
        expect(/^#[0-9a-f]{6}$/i.test(c)).assertTrue();
        const r = parseInt(c.substring(1, 3), 16);
        const g = parseInt(c.substring(3, 5), 16);
        const b = parseInt(c.substring(5, 7), 16);
        const lum = 0.299 * r + 0.587 * g + 0.114 * b;
        // 比纯白深：白字压上去有对比度（否则白字消失）。
        expect(lum < 200).assertTrue();
        // 但不能太深（用户明确说之前的太深了）。
        expect(lum > 90).assertTrue();
        // 中性：三通道差值不超过 30，不能带明显的蓝/青/红色相。
        const spread = Math.max(r, g, b) - Math.min(r, g, b);
        expect(spread <= 30).assertTrue();
      }
      // 与卡片壁纸明确解耦：不再等于 GlassStyle 的饱和蓝。
      expect(bg[0].toUpperCase()).assertNotEqual('#4A8FD4');
    });

    it('inner_page_text_is_white_again_with_a_shadow_for_contrast', 0, () => {
      // 用户第二次反馈：「文字还是白色好看」。
      expect(PagePalette.TEXT.toUpperCase()).assertEqual('#FFFFFFFF');
      // 白字压在中灰底上需要一层柔和黑影才够清晰（不能是全透明）。
      expect(PagePalette.SHADOW.toUpperCase()).assertEqual('#66000000');
      // 分隔线用半透明白，在灰底上仍可见。
      expect(PagePalette.DIVIDER.toUpperCase()).assertEqual('#33FFFFFF');
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
