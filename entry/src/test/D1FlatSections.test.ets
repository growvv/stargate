import { describe, it, expect } from '@ohos/hypium';
import { FlatSections } from '../main/ets/pages/FlatSections';
import type { AtomicFunction } from '../main/ets/model/AtomicFunction';
import { CATEGORIES } from '../main/ets/model/AtomicFunction';

/**
 * D1（真机发现）：AllFunctionsPage 用 ListItemGroup + 双层 ForEach，搜索时 ArkUI
 * 复用旧分组的 ListItem 不回收 → 计数 2 项却渲染 3 行陈旧条目。
 * 修法：改成「扁平 ListItem 列表」，分组标题作为普通 ListItem 行，查询变化时
 * 用 query 参与 key 让 ForEach 整体失效重建。本套件钉住纯逻辑的扁平化与 key。
 */
function fn(id: string, label: string, category: string): AtomicFunction {
  return {
    id: id, label: label, appName: 'App', bundleName: 'com.example',
    category: category,
    route: { kind: 'deeplink', uri: 'fixture://' + id },
    source: 'fixture', confidence: 0.9
  };
}

export default function d1FlatSectionsTest() {
  describe('FlatSections (D1 regression)', () => {
    it('flattens_groups_into_rows_exactly_matching_input', 0, () => {
      const a = fn('a', '支付宝付款码', CATEGORIES[0]);
      const b = fn('b', '微信扫一扫', CATEGORIES[0]);
      const groups = new Map<string, AtomicFunction[]>();
      groups.set('Z', [a, b]);
      groups.set('W', [fn('c', '网易云音乐', CATEGORIES[5])]);
      const rows = FlatSections.flatten(groups);
      // 1 header + 2 items + 1 header + 1 item = 5 行，顺序与输入一致
      expect(rows.length).assertEqual(5);
      expect(rows[0].kind).assertEqual('header');
      expect(rows[0].key).assertEqual('h:|Z');
      expect(rows[1].kind).assertEqual('item');
      expect(rows[1].label).assertEqual('支付宝付款码');
      expect(rows[2].label).assertEqual('微信扫一扫');
      expect(rows[3].kind).assertEqual('header');
      expect(rows[4].label).assertEqual('网易云音乐');
    });
    it('row_keys_include_query_so_recycled_rows_are_invalidated', 0, () => {
      // 真机根因：key 只含分组/条目 id，查询变化后旧 ListItem 被复用。
      // 修法：key 带 query，查询一变所有 key 变化 → ArkUI 不再复用旧行。
      const a = fn('a', '付款码', CATEGORIES[0]);
      const groups = new Map<string, AtomicFunction[]>();
      groups.set('Z', [a]);
      const rowsBefore = FlatSections.flatten(groups, '');
      const rowsAfter = FlatSections.flatten(groups, '支付');
      expect(rowsBefore[1].key).assertEqual('i:|Z:a');
      expect(rowsAfter[1].key).assertEqual('i:支付|Z:a');
      expect(rowsBefore[1].key === rowsAfter[1].key).assertFalse();
    });
    it('empty_groups_produce_no_rows', 0, () => {
      expect(FlatSections.flatten(new Map<string, AtomicFunction[]>()).length).assertEqual(0);
    });
    it('every_row_key_is_unique', 0, () => {
      const groups = new Map<string, AtomicFunction[]>();
      groups.set('Z', [fn('a', 'A', CATEGORIES[0]), fn('b', 'B', CATEGORIES[0])]);
      groups.set('Y', [fn('a', 'A2', CATEGORIES[1])]); // 同 id 不同组，key 仍须唯一
      const rows = FlatSections.flatten(groups, 'q');
      const keys = new Set<string>(rows.map((r) => r.key));
      expect(keys.size).assertEqual(rows.length);
    });
  });
}
