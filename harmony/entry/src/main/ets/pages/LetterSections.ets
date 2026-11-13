import type { AtomicFunction } from '../model/AtomicFunction';
import { PinyinUtil } from '../data/PinyinUtil';

/**
 * 全部功能页（iOS App 资源库搜索态复刻）的字母分组。
 *
 * 参考图（2026-11-09 用户提供）：
 *  - 结果按拼音首字母分段，每段一个大写字母标题；
 *  - 行内是「App 图标 + 文字」，而不是文件夹框网格；
 *  - 右侧 A–Z 索引条可直接跳到对应分段。
 *
 * 与旧 FrameGroups 的区别：这里**不按 4 个一组切框**，每个字母段保留该段
 * 全部条目；排序仍由 PinyinUtil.group 保证（A–Z + '#'，段内按 label 排序）。
 */
export interface LetterSection {
  letter: string;
  items: AtomicFunction[];
}

/** 索引条固定展示 A–Z + '#'（参考图右侧索引始终完整）。 */
const INDEX_LETTERS: string[] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').concat(['#']);

export class LetterSections {
  static indexLetters(): string[] {
    return INDEX_LETTERS.slice();
  }

  static fromItems(items: AtomicFunction[]): LetterSection[] {
    const out: LetterSection[] = [];
    if (!items || items.length === 0) return out;
    const grouped = PinyinUtil.group(items);
    for (const letter of INDEX_LETTERS) {
      const bucket = grouped.get(letter);
      if (bucket && bucket.length > 0) {
        const items_copy: AtomicFunction[] = bucket.slice();
        out.push({ letter: letter, items: items_copy });
      }
    }
    return out;
  }

  /** 索引条字母 → 分段下标；该字母没有内容时返回 -1（点击不滚动）。 */
  static indexOfLetter(sections: LetterSection[], letter: string): number {
    for (let i = 0; i < sections.length; i++) {
      if (sections[i].letter === letter) return i;
    }
    return -1;
  }

  /**
   * 分段 key：字母 + 条目数量 + 条目 id 列表。
   *
   * 真机缺陷（2026-11-11）：搜索页的 ListItemGroup 只按字母做 key，输入新查询
   * 后 ArkUI 按同一 key 复用旧子项 —— 结果只剩 1 条，旧的 D 段条目却还挂着。
   * key 必须包含内容签名，查询一变就整段重建（与 D1 FlatSections 同一条规则）。
   */
  static sectionKey(section: LetterSection): string {
    let ids: string = '';
    for (const fn of section.items) ids += fn.id + '|';
    return section.letter + ':' + section.items.length + ':' + ids;
  }
}

export default LetterSections;
