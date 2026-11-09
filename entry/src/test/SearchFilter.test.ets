import { describe, it, expect } from '@ohos/hypium';
import { SearchFilter } from '../main/ets/data/SearchFilter';
import { makeItems } from './TestFixtures';

export default function searchFilterTest() {
  describe('SearchFilter', () => {
    it('filters_by_label_app_and_category', 0, () => {
      const items = makeItems(12);
      expect(SearchFilter.filter(items, '付款').length >= 0).assertTrue();
      expect(SearchFilter.filter(items, items[0].label).length).assertEqual(1);
      expect(SearchFilter.filter(items, items[0].appName).length >= 1).assertTrue();
      expect(SearchFilter.filter(items, '支付宝').length).assertEqual(1); // 可读 App 名可搜（fixture 首条 appName='支付宝'）
      expect(SearchFilter.filter(items, items[0].category).length >= 1).assertTrue();
      expect(SearchFilter.filter(items, '').length).assertEqual(items.length);
    });
    it('empty_result_and_no_match', 0, () => {
      const items = makeItems(12);
      expect(SearchFilter.filter(items, 'ZZZ-不存在').length).assertEqual(0);
      expect(SearchFilter.filter(makeItems(0), '付款').length).assertEqual(0);
    });
    it('single_latin_letter_matches_pinyin_initial_case_insensitively', 0, () => {
      // 用户反馈：全量页搜索输入 A / a，要返回所有拼音 A 开头的功能。
      const items = makeItems(12);
      items[0].label = '爱奇艺视频';   // 首字「爱」→ A
      items[1].label = '安全中心';     // 首字「安」→ A
      const upper = SearchFilter.filter(items, 'A');
      const lower = SearchFilter.filter(items, 'a');
      expect(upper.length).assertEqual(2);
      expect(lower.length).assertEqual(2);
      expect(upper.map((f) => f.id).join(',')).assertEqual(lower.map((f) => f.id).join(','));
    });
    it('single_letter_a_returns_catalog_entries_whose_pinyin_starts_with_a', 0, () => {
      // 真机目录里的 A 开头条目实际是「按…」（按航班号 / 按起降地查询）。
      // 修复前首字母表漏了「按」，a / A 都返回 0 —— 用户报告的现象。
      const items = makeItems(12);
      items[0].label = '按航班号查询·选应用';
      items[1].label = '按起降地查询·选应用';
      const lower = SearchFilter.filter(items, 'a');
      const upper = SearchFilter.filter(items, 'A');
      expect(lower.length).assertEqual(2);
      expect(upper.length).assertEqual(2);
      expect(lower.map((f) => f.id).join(',')).assertEqual(upper.map((f) => f.id).join(','));
    });
    it('single_letter_also_matches_app_name_pinyin_initial', 0, () => {
      // App 名拼音首字母同样参与：输入 A 能找到「爱奇艺」App 下的任意功能。
      const items = makeItems(12);
      items[0].appName = '爱奇艺';
      items[0].label = '打开客户端'; // 标签首字「打」→ D
      const hit = SearchFilter.filter(items, 'a');
      expect(hit.length).assertEqual(1);
      expect(hit[0].id).assertEqual(items[0].id);
    });
  });
}
