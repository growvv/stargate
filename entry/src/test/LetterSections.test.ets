import { describe, it, expect } from '@ohos/hypium';
import { LetterSections } from '../main/ets/pages/LetterSections';
import { makeItems } from './TestFixtures';

export default function letterSectionsTest() {
  describe('LetterSections', () => {
    it('groups_all_items_by_pinyin_initial_without_chunking', 0, () => {
      // 参考图：每个字母是一段完整列表，不再按 4 个切成文件夹框。
      const items = makeItems(12);
      items[0].label = '爱奇艺视频';
      items[1].label = '安全中心';
      items[2].label = '阿里云';
      const sections = LetterSections.fromItems(items);
      const a = sections.filter((s) => s.letter === 'A')[0];
      expect(a !== undefined).assertTrue();
      expect(a.items.length).assertEqual(3);
      // 段内按 label 排序（PinyinUtil.group 的契约）。
      expect(a.items[0].label).assertEqual('阿里云');
      expect(a.items[1].label).assertEqual('爱奇艺视频');
      expect(a.items[2].label).assertEqual('安全中心');
    });
    it('orders_sections_a_to_z_then_hash', 0, () => {
      const items = makeItems(12);
      items[0].label = '12306';
      const sections = LetterSections.fromItems(items);
      const letters = sections.map((s) => s.letter);
      const sorted = letters.slice().sort((x, y) => {
        const xl = LetterSections.indexLetters().indexOf(x);
        const yl = LetterSections.indexLetters().indexOf(y);
        return xl - yl;
      });
      expect(letters.join(',')).assertEqual(sorted.join(','));
      expect(letters[letters.length - 1]).assertEqual('#');
    });
    it('index_bar_is_full_a_to_z_plus_hash', 0, () => {
      const letters = LetterSections.indexLetters();
      expect(letters.length).assertEqual(27);
      expect(letters[0]).assertEqual('A');
      expect(letters[26]).assertEqual('#');
    });
    it('index_of_letter_returns_section_or_minus_one', 0, () => {
      const items = makeItems(3);
      items[0].label = '爱奇艺';
      const sections = LetterSections.fromItems(items);
      expect(LetterSections.indexOfLetter(sections, 'A')).assertEqual(0);
      expect(LetterSections.indexOfLetter(sections, 'Z')).assertEqual(-1);
      expect(LetterSections.fromItems([]).length).assertEqual(0);
    });
  });
}
