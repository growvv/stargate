/**
 * IOS_VISUAL_SPEC 定稿（Stage −1 / ios-aligned-design.md §3）。
 *
 * Task 0 Ruling：Plan/Spec 里的 CSS 字符串 `backdrop-filter: blur(...)` 是 HTML
 * 草图产物，不是 ArkTS 卡片 API。这里 `blur` 仅为**标记值**（'blur(13px)' / ''）；
 * WidgetCard.ets 实际用 ArkUI `.backdropBlur(13)` / `.backgroundBlurStyle` 呈现材质。
 *
 * 暗色是独立设计的配色与材质，不是简单反相。blur 不可用时 `blur` 必须为空串、
 * 渐变仍在（Task 6 test_theme_degrades_when_blur_unavailable 断言）。
 *
 * D3 修复（真机 2026-11-07）：所有 8 位 hex 改由 ThemeColors 生成（AARRGGBB，
 * alpha 在首位）。旧的手写 '#ffffff30' 被 ArkUI 读成不透明亮黄，是卡片/搜索框
 * 变黄的根因。禁止在此文件再手写 8 位 hex。
 */
import { LIGHT, DARK } from './ThemeColors';

export interface ThemeValues {
  gradient: string;
  cardBg: string;
  blur: string;
  border: string;
  textPrimary: string;
  textSecondary: string;
  radiusCard: number;
  radiusChip: number;
  radiusIcon: number;
}

const LIGHT_GRADIENT: string = 'linear-gradient(150deg,#8e9ff5,#c9a7e8 45%,#f3b6c2)';
const DARK_GRADIENT: string = 'linear-gradient(150deg,#4a5680,#6b5a80 45%,#805a66)';

export class ThemeTokens {
  static build(blurAvailable: boolean, dark: boolean): ThemeValues {
    const blur = blurAvailable ? 'blur(13px)' : '';
    if (dark) {
      return {
        gradient: DARK_GRADIENT,
        cardBg: DARK.cardBg,
        blur: blur,
        border: '1px solid ' + DARK.borderColor,
        textPrimary: DARK.textPrimary,
        textSecondary: DARK.textSecondary,
        radiusCard: 22,
        radiusChip: 16,
        radiusIcon: 12
      };
    }
    return {
      gradient: LIGHT_GRADIENT,
      cardBg: blurAvailable ? LIGHT.cardBg : LIGHT.cardBgNoBlur,
      blur: blur,
      border: '1px solid ' + LIGHT.borderColor,
      textPrimary: LIGHT.textPrimary,
      textSecondary: LIGHT.textSecondary,
      radiusCard: 22,
      radiusChip: 16,
      radiusIcon: 12
    };
  }
}

export default ThemeTokens;
