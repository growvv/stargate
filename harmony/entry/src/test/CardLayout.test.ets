import { describe, it, expect } from '@ohos/hypium';
import { CardLayout } from '../main/ets/form/CardLayout';
import type { CardLayoutTokens, CardLayoutInput } from '../main/ets/form/CardLayout';

/**
 * 2026-11-11 真机（Mate 60，4×4 卡片约 326×342vp）布局重叠修复的回归。
 *
 * 旧实现把 tileSize=60 / 字号 10.5 / 框标签 15 / chip 13.5 全部写死，
 * 内容总高超过卡片可用高度，框内第二行图标与框下标签压到分类 chips 上。
 * 新实现按实测宽高推导，这里钉住「内容高度不超过可用高度」这条硬约束。
 */

/**
 * 复算一个文件夹框的内容高度（两个框是并排的 46%，不是上下堆叠）。
 * 与 CardLayout.compute 内部公式保持一致：两行（图标 + 功能名）+ 框内上下
 * 内边距 + 框下标签。
 */
function contentHeight(t: CardLayoutTokens): number {
  return 2 * (t.tileSize + 3 + t.tileLabelLines * t.tileLabelLine) + 18 + 22 + t.frameGap;
}

/** chips 区高度（按实际类目名贪心排布）。 */
function chipsHeight(t: CardLayoutTokens, names: string[]): number {
  const rows = CardLayout.chipRowCount(names, t.chipFont, t.chipPadX, t.widthVp - 20);
  return rows * (t.chipFont * 1.45 + t.chipPadY * 2 + 8);
}

const NINE: string[] = ['支付', '购物', '出行', '社交', '生活', '娱乐', '健康运动', '工具效率', '其他'];

export default function cardLayoutTest() {
  describe('CardLayout (device-adaptive sizing)', () => {
    it('phone_4x4_content_fits_inside_the_card', 0, () => {
      // 真机实测：Mate 60 的 4×4 卡片约 326×342vp。这是曾经重叠的那台设备。
      const input: CardLayoutInput = {
        size: { widthPx: 1065, heightPx: 1112 }, density: 3.25, categoryNames: NINE, frameCount: 2
      };
      const t = CardLayout.compute(input);
      const header = 12 + Math.round(t.titleFont * 1.4);
      const used = header + contentHeight(t) + chipsHeight(t, NINE) + 8;
      // 内容总高必须 ≤ 卡片高度，否则 layoutWeight 分配不够就会溢出到 chips。
      expect(used <= 342).assertTrue();
      // 图标不能小到看不清，也不能大到撑破宽度（半框内两个图标）。
      expect(t.tileSize >= 34).assertTrue();
      expect(t.tileSize * 2 <= 326 / 2).assertTrue();
    });

    it('tablet_4x4_gets_larger_tiles_than_phone', 0, () => {
      // 平板 4×4 卡片明显更大：同一份代码应给出更大的图标，而不是固定 60。
      const phone = CardLayout.compute({
        size: { widthPx: 1065, heightPx: 1112 }, density: 3.25, categoryNames: NINE, frameCount: 2
      });
      const tablet = CardLayout.compute({
        size: { widthPx: 1690, heightPx: 1690 }, density: 3.25, categoryNames: NINE, frameCount: 2
      });
      expect(tablet.tileSize > phone.tileSize).assertTrue();
      expect(tablet.density).assertEqual('roomy');
    });

    it('header_only_reserves_room_for_the_title', 0, () => {
      // 用户拍板（2026-11-11）：去掉 StarGate 下面的小字，顶栏只剩标题。
      // 顶栏高度因此只跟标题字号走，短卡片不必再靠「丢副标题」省空间，
      // 省下的 17vp 直接还给图标网格。
      const tall = CardLayout.compute({
        size: { widthPx: 1170, heightPx: 1235 }, density: 3.25, categoryNames: NINE, frameCount: 2
      });
      const short = CardLayout.compute({
        size: { widthPx: 1170, heightPx: 910 }, density: 3.25, categoryNames: NINE, frameCount: 2
      });
      expect(tall.titleFont > 0).assertTrue();
      expect(tall.titleFont).assertEqual(short.titleFont);
      // 短卡片拿到的图标只会更小（高度预算更紧），不会更大。
      expect(short.tileSize <= tall.tileSize).assertTrue();
    });

    it('unknown_size_falls_back_to_a_safe_design_baseline', 0, () => {
      const t = CardLayout.compute({
        size: { widthPx: 0, heightPx: 0 }, density: 0, categoryNames: NINE, frameCount: 2
      });
      expect(t.widthVp).assertEqual(360);
      expect(t.heightVp).assertEqual(360);
      expect(t.tileSize > 0).assertTrue();
    });

    it('chip_row_count_reflects_actual_category_names', 0, () => {
      // 9 个两字类目在 326vp 宽下大约排 2 行；名字变长会多出一行。
      const short = CardLayout.chipRowCount(NINE, 12.5, 10, 306);
      const long = CardLayout.chipRowCount(
        ['支付结算', '购物返利', '出行导航', '社交聊天', '生活服务',
          '娱乐影音', '健康运动', '工具效率', '其他应用'], 12.5, 10, 306);
      expect(short >= 2).assertTrue();
      expect(long > short).assertTrue();
    });

    it('label_lines_shrink_before_the_tile_becomes_unreadable', 0, () => {
      // 高度极紧时先退到一行功能名，而不是把图标压成一个小点。
      const tight = CardLayout.compute({
        size: { widthPx: 975, heightPx: 780 }, density: 3.25, categoryNames: NINE, frameCount: 2
      });
      expect(tight.tileLabelLines).assertEqual(1);
      expect(tight.tileSize >= 30).assertTrue();
    });

    it('tokens_are_monotonic_and_bounded_across_a_size_sweep', 0, () => {
      // 扫一遍常见尺寸：任何一档都不能出现负数 / 超出卡片的高度。
      const sizes: number[][] = [[975, 845], [1065, 1112], [1170, 1170], [1300, 1365], [1690, 1690]];
      for (const s of sizes) {
        const t = CardLayout.compute({
          size: { widthPx: s[0], heightPx: s[1] }, density: 3.25, categoryNames: NINE, frameCount: 2
        });
        expect(t.tileSize >= 30).assertTrue();
        expect(t.tileSize <= 96).assertTrue();
        expect(t.tileLabelFont > 0).assertTrue();
        expect(t.chipFont > 0).assertTrue();
        const header = 12 + Math.round(t.titleFont * 1.4);
        const used = header + contentHeight(t) + chipsHeight(t, NINE) + 8;
        expect(used <= s[1] / 3.25).assertTrue();
      }
    });
  });
}
