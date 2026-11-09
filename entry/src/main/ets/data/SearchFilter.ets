import type { AtomicFunction } from '../model/AtomicFunction';
import { PinyinUtil } from './PinyinUtil';

/**
 * 分类/全量页的搜索过滤（产品 Spec §4）。
 * 匹配可读功能名 label / 可读 App 名 appName / 分类名 category，大小写不敏感子串；
 * **不拿 bundleName 当 App 名**（B2′/D2 连带修复：bundleName 是包名，不是可读名）。
 * query 为空返回全量；无匹配返回空数组（不崩）。
 *
 * 拼音首字母（2026-11-09 用户反馈）：输入单个拉丁字母 A–Z / a–z 时，
 * 除原有子串匹配外，还返回「功能名或 App 名拼音首字母命中」的条目，
 * 例如输入 a 能列出所有「爱… / 安…」开头的功能和「爱奇艺」下的功能。
 */
export class SearchFilter {
  static filter(items: AtomicFunction[], query: string): AtomicFunction[] {
    if (!items || items.length === 0) return [];
    if (!query) return items.slice();
    const q = query.trim().toLowerCase();
    if (!q) return items.slice();
    const singleLetter: string = q.length === 1 && q >= 'a' && q <= 'z' ? q.toUpperCase() : '';
    return items.filter((f) => {
      if (singleLetter !== '') {
        if (PinyinUtil.initial(f.label) === singleLetter) return true;
        if (PinyinUtil.initial(f.appName) === singleLetter) return true;
      }
      return f.label.toLowerCase().includes(q) ||
        f.appName.toLowerCase().includes(q) ||
        f.category.toLowerCase().includes(q);
    });
  }
}

export default SearchFilter;
