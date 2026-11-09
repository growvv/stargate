import { describe, it, expect } from '@ohos/hypium';
import { ThemeTokens } from '../main/ets/form/ThemeTokens';

export default function themeTokensTest() {
  describe('ThemeTokens', () => {
    it('theme_degrades_when_blur_unavailable', 0, () => {
      const t = ThemeTokens.build(false, false);
      expect(t.blur).assertEqual('');
      expect(t.gradient).assertContain('#8e9ff5');
      const d = ThemeTokens.build(false, true);
      expect(d.cardBg).assertEqual('#30000000'); // D3：AARRGGBB
      expect(d.textPrimary).assertEqual('#ffffff');
    });
    it('light_blur_and_dark_are_independent', 0, () => {
      const light = ThemeTokens.build(true, false);
      expect(light.blur).assertEqual('blur(13px)');
      expect(light.cardBg).assertEqual('#30ffffff'); // D3：AARRGGBB
      expect(light.radiusCard).assertEqual(22);
      expect(light.radiusChip).assertEqual(16);
      expect(light.radiusIcon).assertEqual(12);
      const dark = ThemeTokens.build(true, true);
      expect(dark.gradient).assertContain('#4a5680');
      expect(dark.textSecondary).assertEqual('#e6ffffff'); // D3：AARRGGBB
      expect(dark.border).assertEqual('1px solid #33ffffff'); // D3
    });
  });
}
