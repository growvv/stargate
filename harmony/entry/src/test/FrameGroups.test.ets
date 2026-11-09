import { describe, it, expect } from '@ohos/hypium';
import { FrameGroups } from '../main/ets/pages/FrameGroups';
import type { FrameGroup } from '../main/ets/pages/FrameGroups';
import { PinyinUtil } from '../main/ets/data/PinyinUtil';
import { makeItems } from './TestFixtures';

/**
 * 精准复刻参考图：卡片 / 内页都不能是「普通列表」，必须是「外层玻璃文件夹框 →
 * 内层 2×2 功能图标框」的嵌套框结构。FrameGroups 把一维功能数组切成
 * 「每个文件夹 4 个功能」的分组；不足 4 个的末组按实际数量（B2′ 不凑数）。
 *
 * 这是纯逻辑（无 SDK），可被 Node 单测直接驱动。
 */
export default function frameGroupsTest() {
  describe('FrameGroups (nested folder frames, not a plain list)', () => {
    it('chunks_items_into_folder_frames_of_four', 0, () => {
      const groups: FrameGroup[] = FrameGroups.of(makeItems(8), 4);
      expect(groups.length).assertEqual(2);
      expect(groups[0].items.length).assertEqual(4);
      expect(groups[1].items.length).assertEqual(4);
      expect(groups[0].key).assertNotEqual(groups[1].key);
    });

    it('last_frame_keeps_remainder_without_padding', 0, () => {
      const groups = FrameGroups.of(makeItems(6), 4);
      expect(groups.length).assertEqual(2);
      expect(groups[0].items.length).assertEqual(4);
      expect(groups[1].items.length).assertEqual(2); // 6 = 4 + 2，不补空格
    });

    it('empty_catalog_yields_no_frames', 0, () => {
      expect(FrameGroups.of([], 4).length).assertEqual(0);
    });

    it('keys_include_query_so_search_rebuilds_all_frames_D1', 0, () => {
      // D1 回归：搜索词变化必须让所有框的 key 失效，杜绝陈旧功能框残留。
      const a = FrameGroups.of(makeItems(4), 4, '支付');
      const b = FrameGroups.of(makeItems(4), 4, '淘宝');
      expect(a[0].key).assertNotEqual(b[0].key);
      expect(a[0].key.includes('支付')).assertTrue();
    });

    it('frame_label_uses_category_when_group_is_homogeneous', 0, () => {
      // 参考图：外层框下方带分类标签（建议 / 社交 / 效率 …）。
      const items = makeItems(2);
      const g = FrameGroups.of(items, 4)[0];
      expect(g.label.length > 0).assertTrue();
    });

    it('per_frame_2x2_rows_split_exactly', 0, () => {
      // 每个外层框内是 2×2：前两个在第一行，后两个在第二行。
      const g = FrameGroups.of(makeItems(4), 4)[0];
      const rows = FrameGroups.rows(g, 2);
      expect(rows.length).assertEqual(2);
      expect(rows[0].length).assertEqual(2);
      expect(rows[1].length).assertEqual(2);
      expect(rows[0][0].id).assertEqual(g.items[0].id);
      expect(rows[1][0].id).assertEqual(g.items[2].id);
    });

    it('from_pinyin_preserves_AZ_grouping_as_frame_labels', 0, () => {
      // 全量页必须保留「按拼音 A–Z 排序」（既有功能），但不再用普通 List：
      // 每个拼音分组变成一个外层玻璃文件夹框，框标签 = 该组字母。
      const grouped = PinyinUtil.group(makeItems(8));
      const frames = FrameGroups.fromPinyin(grouped, 'q');
      expect(frames.length).assertEqual(grouped.size);
      let i = 0;
      const keys: string[] = [];
      grouped.forEach((_items, k) => { keys.push(k); });
      for (const f of frames) {
        expect(f.label).assertEqual(keys[i]);
        expect(f.items.length > 0).assertTrue();
        expect(f.key.includes('q:')).assertTrue(); // query 进 key（D1）
        i++;
      }
    });

    it('pinyin_frames_chunk_large_letters_into_multiple_folder_frames', 0, () => {
      // 一个字母桶超过 4 个功能时，拆成多个文件夹框（每框 ≤4），不丢条目。
      const many = makeItems(6);
      const grouped = PinyinUtil.group(many);
      const frames = FrameGroups.fromPinyin(grouped, '');
      let total = 0;
      for (const f of frames) {
        expect(f.items.length <= 4).assertTrue();
        total += f.items.length;
      }
      expect(total).assertEqual(6);
    });
  });
}
