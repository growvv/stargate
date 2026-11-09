import { describe, it, expect } from '@ohos/hypium';
import { ThemeColors } from '../main/ets/form/ThemeColors';
import { ThemeTokens } from '../main/ets/form/ThemeTokens';

/**
 * D3（真机发现）：ArkUI 把 8 位 hex 颜色按 AARRGGBB 解析，而不是 CSS 的 RGBA。
 * 旧值 '#ffffff30' 被读成 rgba(255,255,48,1) 不透明亮黄 —— 卡片 updateForm 后
 * 整块变黄、各页搜索框也一直是黄。本套件钉住「ARGB 顺序 + 所有 token 合法」。
 */
export default function d3ThemeColorsTest() {
  describe('ThemeColors (D3 regression)', () => {
    it('hex8_is_argb_not_rgba', 0, () => {
      // 同样的「30/255 透明度 + 白」，AARRGGBB 必须是 #30ffffff；
      // 旧的 #ffffff30 首位 FF = 不透明，末位 30 = 蓝色分量 → 亮黄。
      expect(ThemeColors.hex8(255, 255, 255, 0x30)).assertEqual('#30ffffff');
      expect(ThemeColors.hex8(0, 0, 0, 0x30)).assertEqual('#30000000');
      expect(ThemeColors.hex8(255, 255, 255, 0xff)).assertEqual('#ffffffff');
    });
    it('hex8_pads_single_digit_channels', 0, () => {
      expect(ThemeColors.hex8(0, 0, 0, 0)).assertEqual('#00000000');
      expect(ThemeColors.hex8(1, 2, 3, 4)).assertEqual('#04010203');
    });
    it('all_theme_values_are_valid_argb_or_opaque_rgb', 0, () => {
      // 每个字段要么是 6 位 RGB、要么是合法 8 位 ARGB（长度/十六进制都合格），
      // 且 8 位值的首位必须是透明度通道（不能是 FF 之外的「假透明」）。
      const vals = [
        ThemeColors.LIGHT.cardBg, ThemeColors.LIGHT.cardBgNoBlur,
        ThemeColors.LIGHT.borderColor, ThemeColors.LIGHT.textPrimary,
        ThemeColors.LIGHT.textSecondary, ThemeColors.LIGHT.divider,
        ThemeColors.DARK.cardBg, ThemeColors.DARK.borderColor,
        ThemeColors.DARK.textPrimary, ThemeColors.DARK.textSecondary,
        ThemeColors.DARK.divider
      ];
      for (const v of vals) {
        expect(/^#([0-9a-f]{6}|[0-9a-f]{8})$/.test(v)).assertTrue();
      }
      // 半透明材质：alpha 必须真的是 0x30 / 0x4d 一类，而不是被读成 FF。
      expect(ThemeColors.LIGHT.cardBg.startsWith('#30')).assertTrue();
      expect(ThemeColors.LIGHT.cardBgNoBlur.startsWith('#4d')).assertTrue();
      expect(ThemeColors.DARK.cardBg.startsWith('#30')).assertTrue();
      expect(ThemeColors.LIGHT.textSecondary.startsWith('#f2')).assertTrue();
      expect(ThemeColors.DARK.textSecondary.startsWith('#e6')).assertTrue();
    });
    it('theme_tokens_expose_argb_values', 0, () => {
      const light = ThemeTokens.build(true, false);
      expect(light.cardBg).assertEqual('#30ffffff');
      expect(light.textSecondary).assertEqual('#f2ffffff');
      expect(light.border).assertContain('#55ffffff');
      const dark = ThemeTokens.build(false, true);
      expect(dark.cardBg).assertEqual('#30000000');
      expect(dark.textSecondary).assertEqual('#e6ffffff');
    });
  });
}
