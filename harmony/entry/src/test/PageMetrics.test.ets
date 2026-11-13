import { describe, it, expect } from '@ohos/hypium';
import { PageMetricsCalc } from '../main/ets/form/PageMetrics';
import type { PageMetrics } from '../main/ets/form/PageMetrics';

/**
 * 2026-11-11 用户反馈：「你写这些 UI 上面的写法，尽量不要用绝对的，不然的话
 * 后面会换到平板上的，可能就不是很兼容平板」。
 *
 * 旧实现把搜索框高度（46）、字号（16）、圆角（23）、分类页图标边长（60）
 * 全部写死 —— 手机刚好，平板就是一个又小又挤的搜索框和一张 60vp 的小图标
 * 网格。这里钉住三条约束：随宽度单调增长、有上下限、比例关系恒成立。
 */
export default function pageMetricsTest() {
  describe('PageMetrics (width-derived inner-page sizing)', () => {
    it('phone_baseline_matches_the_390vp_design_width', 0, () => {
      const m = PageMetricsCalc.compute(390);
      expect(m.widthVp).assertEqual(390);
      // 手机基准：搜索框 46vp 高、16 号字 —— 与之前真机调好的手感一致。
      expect(m.searchHeight).assertEqual(46);
      expect(m.searchFont).assertEqual(16);
      expect(m.searchRadius).assertEqual(23);
    });

    it('tablet_gets_a_proportionally_larger_search_bar', 0, () => {
      // 平板（约 800vp 宽）不能还是 46vp 高、16 号字。
      const phone = PageMetricsCalc.compute(390);
      const tablet = PageMetricsCalc.compute(800);
      expect(tablet.searchHeight > phone.searchHeight).assertTrue();
      expect(tablet.searchFont > phone.searchFont).assertTrue();
      expect(tablet.tileSize > phone.tileSize).assertTrue();
      expect(tablet.titleFont > phone.titleFont).assertTrue();
    });

    it('search_pill_stays_capsule_shaped_at_every_width', 0, () => {
      // 圆角必须恒等于高度的一半，否则换设备就变成圆角矩形。
      for (const w of [320, 390, 480, 600, 800, 1000]) {
        const m = PageMetricsCalc.compute(w);
        expect(m.searchRadius).assertEqual(Math.round(m.searchHeight / 2));
      }
    });

    it('category_tiles_fit_four_across_without_overflow', 0, () => {
      // 一行 4 个图标：页面留白 + 外框内边距 + 3 个间距 + 4 个图标 ≤ 容器宽度。
      for (const w of [320, 390, 480, 600, 800, 1000, 1200]) {
        const m = PageMetricsCalc.compute(w);
        // 每格固定 1/4 行宽（页面侧 width('25%')），图标必须装进格子。
        const innerW = w - m.pagePad * 2 - m.framePad * 2;
        expect(m.tileSize <= innerW / 4).assertTrue();
      }
    });

    it('sizes_are_clamped_so_extremes_stay_usable', 0, () => {
      // 极窄（分屏）不挤成一团，极宽（大平板）不夸张放大。
      const tiny = PageMetricsCalc.compute(240);
      const huge = PageMetricsCalc.compute(2000);
      expect(tiny.searchHeight >= 40).assertTrue();
      expect(tiny.searchFont >= 14).assertTrue();
      expect(tiny.tileSize >= 36).assertTrue();
      expect(huge.searchHeight <= 72).assertTrue();
      expect(huge.searchFont <= 24).assertTrue();
      expect(huge.tileSize <= 120).assertTrue();
      // 索引条至少保留手指可点的宽度。
      expect(tiny.indexWidth >= 22).assertTrue();
    });

    it('unknown_width_falls_back_to_the_phone_baseline', 0, () => {
      // 首帧拿不到 onAreaChange 时不能算出 0 尺寸。
      const m = PageMetricsCalc.compute(0);
      expect(m.widthVp).assertEqual(390);
      expect(m.searchHeight).assertEqual(46);
      expect(PageMetricsCalc.baseline().searchHeight).assertEqual(m.searchHeight);
    });

    it('metrics_are_monotonic_across_a_width_sweep', 0, () => {
      // 宽度递增时关键尺寸不能反而变小（否则布局会跳）。
      let prev: PageMetrics | undefined = undefined;
      for (const w of [300, 360, 390, 450, 520, 600, 700, 800, 900]) {
        const m = PageMetricsCalc.compute(w);
        if (prev !== undefined) {
          expect(m.searchHeight >= prev.searchHeight).assertTrue();
          expect(m.searchFont >= prev.searchFont).assertTrue();
          expect(m.tileSize >= prev.tileSize).assertTrue();
          expect(m.pagePad >= prev.pagePad).assertTrue();
        }
        prev = m;
      }
    });

    it('all_metrics_are_positive_numbers', 0, () => {
      const m = PageMetricsCalc.compute(390);
      const values: number[] = [
        m.searchHeight, m.searchFont, m.searchRadius, m.searchPadX, m.searchIconSize,
        m.titleFont, m.rowFont, m.rowSubFont, m.rowIconSize, m.tileSize, m.tileRadius,
        m.pagePad, m.indexWidth
      ];
      for (const v of values) {
        expect(v > 0).assertTrue();
        expect(Number.isFinite(v)).assertTrue();
      }
    });
  });
}
