import { describe, it, expect } from '@ohos/hypium';
import { readFileSync } from 'node:fs';

/**
 * 精准复刻参考图 1（iOS App Library）：文件夹框下方直接是分类标签，
 * 再往下是图标网格 —— 没有「按分类浏览」这类小节标题。
 * 真机截图（V0）证实该标题与两个框下标签在同一行重叠，是必须去掉的多余 chrome。
 * 这里以静态源断言钉住「卡片不渲染普通小节标题」这条视觉约束。
 */
export default function cardChromeTest() {
  describe('CardChrome (precise iOS App Library replication)', () => {
    it('card_has_no_redundant_section_header_overlapping_frame_labels', 0, () => {
      const src = readFileSync(
        new URL('../main/ets/form/WidgetCard.ets', import.meta.url), 'utf8');
      expect(src.includes("Text('按分类浏览')")).assertFalse();
    });

    it('card_chrome_still_keeps_functional_entries', 0, () => {
      // 去掉的是多余「小节标题」，不是功能入口：搜索 / 分类 chips / 卡片标题仍在。
      const src = readFileSync(
        new URL('../main/ets/form/WidgetCard.ets', import.meta.url), 'utf8');
      // 用户拍板（2026-11-11）：入口按实际功能命名 ——「更多」改为「搜索」，
      // 因为点进去就是一个带搜索框的 A–Z 列表，叫「更多」会让用户以为是设置项。
      expect(src.includes("Text('搜索')")).assertTrue();
      // 「探索」是工程诊断页，不进面向用户的卡片顶栏（仍可从设置进入）。
      expect(src.includes("Text('探索')")).assertFalse();
      // 用户拍板：产品名改为 StarGate，不再出现「功能面板」。
      expect(src.includes("'StarGate'")).assertTrue();
      expect(src.includes('功能面板')).assertFalse();
      expect(src.includes('categories')).assertTrue();
    });

    it('tile_label_has_a_fixed_height_so_both_frames_stay_aligned', 0, () => {
      // 真机 2026-11-11：同框重名消歧后，标签变成「微博 · 存储空间」，换行把
      // 那一格撑高，两个框的框下标签（推荐 / 最近添加）就错开了。
      // 标签必须占固定高度（行数 × 行高），文字长短不改变格子高度。
      const src = readFileSync(
        new URL('../main/ets/form/WidgetCard.ets', import.meta.url), 'utf8');
      expect(src.includes('.height(this.tileLabelLine * this.tileLabelLines)')).assertTrue();
      // 仍然保持单行省略兜底，不能靠溢出显示。
      expect(src.includes('.maxLines(this.tileLabelLines)')).assertTrue();
      expect(src.includes('TextOverflow.Ellipsis')).assertTrue();
    });
  });
}
