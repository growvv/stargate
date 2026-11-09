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
      // 去掉的是多余「小节标题」，不是功能入口：更多 / 分类 chips / 卡片标题仍在。
      const src = readFileSync(
        new URL('../main/ets/form/WidgetCard.ets', import.meta.url), 'utf8');
      expect(src.includes("'更多 ›'")).assertTrue();
      // 用户拍板：产品名改为 StarGate，不再出现「功能面板」。
      expect(src.includes("'StarGate'")).assertTrue();
      expect(src.includes('功能面板')).assertFalse();
      expect(src.includes('categories')).assertTrue();
    });
  });
}
